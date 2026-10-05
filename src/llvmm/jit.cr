# src/llvmm/jit.cr

# High-level facade over LLVM's ORCv2 JIT stack (`LLVMM::Orc::LLJIT`).
#
# Modules are built in the JIT's own `#context`, submitted with `#add_module`, and
# resolved into callable Crystal procs with `#function`. Marked experimental because
# the ORCv2 C API it wraps is marked experimental by LLVM.
#
# Construction initializes the native target (`LLVMM.init_native_target`) and creates
# a target machine for the host CPU (default optimization level, PIC relocation,
# GlobalISel disabled). The JIT owns the underlying `Orc::LLJIT` instance, its
# thread-safe context, and every module passed to `#add_module`; `#dispose` releases
# all of them and also runs on GC finalization. Prefer the block form of `.new` to
# guarantee disposal:
#
# ```
# LLVMM::JIT.new do |jit|
#   mod = jit.new_module("example")
#   add = mod.functions.add("add", [jit.context.int32, jit.context.int32], jit.context.int32)
#   add.basic_blocks.append("entry") do |builder|
#     builder.ret(builder.add(add.params[0], add.params[1]))
#   end
#   jit.add_module(mod)
#
#   jit.function("add", Int32, Int32, Int32).call(19, 23) # => 42
# end
# ```
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::JIT
  # The context in which modules for this JIT are built.
  # Owned by the JIT and disposed together with it.
  getter context : LLVMM::Context

  def initialize
    LLVMM.init_native_target
    @ts_ctx = uninitialized LLVMM::Orc::ThreadSafeContext
    @context = uninitialized LLVMM::Context
    {% if LibLLVMM::IS_LT_210 %}
      @ts_ctx = LLVMM::Orc::ThreadSafeContext.new
      @context = @ts_ctx.context
    {% else %}
      @context = LLVMM::Context.new
      @ts_ctx = LLVMM::Orc::ThreadSafeContext.new(@context)
    {% end %}
    @arg_types = {} of String => Array(String)
    @ret_types = {} of String => String
    @disposed  = false
    triple     = LLVMM.default_target_triple
    machine = LibLLVMM.create_target_machine(LLVMM::Target.from_triple(triple), triple, LLVMM.host_cpu_name, "",
      LLVMM::CodeGenOptLevel::Default, LLVMM::RelocMode::PIC, LLVMM::CodeModel::Default)
    raise "Couldn't create target machine for #{triple}" if machine.null?
    LibLLVMM.set_target_machine_global_isel(machine, false)
    jtmb    = LibLLVMM.orc_jit_target_machine_builder_create_from_target_machine(machine)
    builder = LLVMM::Orc::LLJITBuilder.new
    LibLLVMM.orc_lljit_builder_set_jit_target_machine_builder(builder, jtmb)
    @jit = LLVMM::Orc::LLJIT.new(builder)
  end

  # Creates a JIT and yields it, disposing it when the block returns.
  def self.new(&)
    jit = new
    yield jit ensure jit.dispose
  end

  # Creates a new module in this JIT's `#context` with its target triple set to the
  # host default. The caller owns the module until `#add_module` takes ownership of it.
  def new_module(name : String) : LLVMM::Module
    @context.new_module(name).tap { |mod| mod.target = LLVMM.default_target_triple }
  end

  # Takes ownership of *mod* and adds it to the main JITDyLib for compilation.
  # The module must have been built in this JIT's `#context` (see `#new_module`) and
  # must not be disposed, modified, or added again afterwards. The signatures of the
  # module's functions are recorded for the runtime checks performed by `#function`.
  def add_module(mod : LLVMM::Module) : Nil
    mod.functions.each do |func|
      fun_ty = func.function_type
      @arg_types[func.name] = fun_ty.params_types.map(&.inspect)
      @ret_types[func.name] = fun_ty.return_type.inspect
    end
    tsm = LLVMM::Orc::ThreadSafeModule.new(mod, @ts_ctx)
    @jit.add_llvm_ir_module(@jit.main_jit_dylib, tsm)
  end

  # Lets JIT'd code resolve symbols against the current process by adding a dynamic
  # library search generator for it to the main JITDyLib.
  def link_process_symbols : Nil
    @jit.main_jit_dylib.link_symbols_from_current_process(@jit.global_prefix)
  end

  # Lets JIT'd code resolve symbols against the shared library at *path* by adding a
  # dynamic library search generator for it to the main JITDyLib.
  def link_symbols_from_path(path : String) : Nil
    @jit.main_jit_dylib.link_symbols_from_path(path, @jit.global_prefix)
  end

  # Defines *name* as an absolute symbol pointing at *address* in the main JITDyLib,
  # e.g. to expose a Crystal `fun` to JIT'd code.
  def define(name : String, address : Void*) : Nil
    session = LibLLVMM.orc_lljit_get_execution_session(@jit)
    entry   = LibLLVMM.orc_execution_session_intern(session, name.check_no_null_byte)
    pairs   = LibC.malloc(LibC::SizeT.new(sizeof(LibLLVMM::OrcCSymbolMapPair))).as(LibLLVMM::OrcCSymbolMapPairs)
    pairs[0] = LibLLVMM::OrcCSymbolMapPair.new(name: entry, address: address.address.to_u64)
    unit = LibLLVMM.orc_absolute_symbols(pairs, LibC::SizeT.new(1))
    LLVMM.assert LibLLVMM.orc_jit_dylib_define(@jit.main_jit_dylib, unit)
    LibC.free(pairs.as(Void*))
  end

  # Looks up the JIT-compiled function *name* and returns it as a callable Crystal
  # `Proc`.
  #
  # The last entry in *types* is the return type; the preceding ones are the argument
  # types, so at least one type must be given (compile-time error otherwise). Before
  # the lookup, the requested signature is checked at runtime against the functions
  # recorded by `#add_module`: an unknown name, wrong arity, or a mismatched argument
  # or return type raises. A symbol that resolves to a null address also raises.
  #
  # Crystal types map to LLVM types as follows:
  #
  # - `Bool` -> `i1`
  # - `Int8`–`Int128` and `UInt8`–`UInt128` -> `i8`–`i128`
  # - `Float32` / `Float64` -> `float` / `double`
  # - `Pointer(T)` -> opaque pointer (`ptr`)
  # - `StaticArray(T, N)` -> `[N x T]`, passed by value
  # - `Struct` -> literal struct of its instance variables, passed by value
  # - `Nil` -> `void` (valid as the return type only; a compile-time error elsewhere)
  #
  # Aggregate element and field types are mapped recursively and must themselves be
  # mappable; any other type is a compile-time error. The returned proc is only valid
  # until the JIT is disposed.
  def function(name : String, *types : *T) forall T
    {% if T.size == 0 %}
      {% raise "LLVMM::JIT#function requires at least a return type" %}
    {% end %}
    expected_args = [] of LLVMM::Type
    expected_ret  = @context.void_pointer
    {% for t, i in T.type_vars %}
      {% if i == T.type_vars.size - 1 %}
        {% if t < Pointer.class %}
          expected_ret = @context.void_pointer
        {% else %}
          expected_ret = llvm_type_of(typeof(types[{{i}}].allocate))
        {% end %}
      {% else %}
        {% if t.name.stringify == "Nil.class" %}
          {% raise "Nil is only valid as the return type of a JIT function" %}
        {% end %}
        {% if t < Pointer.class %}
          expected_args << @context.void_pointer
        {% else %}
          expected_args << llvm_type_of(typeof(types[{{i}}].allocate))
        {% end %}
      {% end %}
    {% end %}
    verify_signature!(name, expected_args, expected_ret)
    address = @jit.lookup(name)
    raise "JIT symbol '#{name}' resolved to a null address" if address.null?
    {{ (
         args = [] of String
         T.type_vars.each_with_index do |t, i|
           unless i == T.type_vars.size - 1
             args << (t < Pointer.class ? "a#{i} : typeof(types[#{i}].null)" : "a#{i} : typeof(types[#{i}].allocate)")
           end
         end
         last = T.type_vars.size - 1
         ret  = T.type_vars.last < Pointer.class ? "types[#{last}].null" : "types[#{last}].allocate"
         "typeof(->(" + args.join(", ") + ") : typeof(" + ret + ") { raise \"unreachable\" }).new(address, Pointer(Void).null)"
       ).id }}
  end

  # Disposes the underlying `Orc::LLJIT` instance and its thread-safe context.
  # Idempotent. Invalidates `#context`, all added modules, and every proc returned
  # by `#function`.
  def dispose : Nil
    return if @disposed
    @disposed = true
    @jit.dispose
    @ts_ctx.dispose
  end

  def finalize
    dispose
  end

  private def verify_signature!(name : String, expected_args : Array(LLVMM::Type), expected_ret : LLVMM::Type) : Nil
    actual_args = @arg_types[name]?
    actual_args || raise "no function named '#{name}' in the modules added to this JIT"
    signature = "#{@ret_types[name]}(#{actual_args.join(", ")})"

    unless actual_args.size == expected_args.size
      raise "JIT function '#{name}' has signature #{signature} but #{expected_args.size} argument type(s) were given"
    end
    actual_args.each_with_index do |actual, i|
      unless actual == expected_args[i].inspect
        raise "JIT function '#{name}' has signature #{signature}: argument #{i} is #{actual}, not #{expected_args[i].inspect}"
      end
    end
    unless @ret_types[name] == expected_ret.inspect
      raise "JIT function '#{name}' has signature #{signature}: returns #{@ret_types[name]}, not #{expected_ret.inspect}"
    end
  end

  private def llvm_type_of(type : T.class) : LLVMM::Type forall T
    {% if T == Nil %}
      @context.void
    {% elsif T == Bool %}
      @context.int1
    {% elsif T == Int8 %}
      @context.int8
    {% elsif T == Int16 %}
      @context.int16
    {% elsif T == Int32 %}
      @context.int32
    {% elsif T == Int64 %}
      @context.int64
    {% elsif T == Int128 %}
      @context.int128
    {% elsif T == UInt8 %}
      @context.int(8)
    {% elsif T == UInt16 %}
      @context.int(16)
    {% elsif T == UInt32 %}
      @context.int(32)
    {% elsif T == UInt64 %}
      @context.int(64)
    {% elsif T == UInt128 %}
      @context.int128
    {% elsif T == Float32 %}
      @context.float
    {% elsif T == Float64 %}
      @context.double
    {% elsif T < Pointer %}
      @context.void_pointer
    {% elsif T < StaticArray %}
      llvm_type_of({{T.type_vars[0]}}).array({{T.type_vars[1]}})
    {% elsif T < Struct %}
      fields = [] of LLVMM::Type
      {% for ivar in T.instance_vars %}
        fields << llvm_type_of({{ivar.type}})
      {% end %}
      @context.struct(fields)
    {% else %}
      {% raise "LLVMM::JIT cannot map Crystal type #{T} to an LLVM type" %}
    {% end %}
  end
end
