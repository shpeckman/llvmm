# src/llvmm/context.cr
# An LLVM context (`LLVMContext`): owns every type, constant, and metadata
# node created within it, as well as the modules built in it.
#
# The context is disposed by the garbage collector (via `finalize`) unless it
# was created with `dispose_on_finalize: false` or ownership was handed off
# with `take_ownership` (e.g. to `Orc::ThreadSafeContext`). Finalization also
# disposes every `Builder` created through `new_builder`, and invalidates all
# modules, types, and values belonging to the context.
#
# ```
# context = LLVMM::Context.new
# mod     = context.new_module("example")
#
# func = mod.functions.add("add", [context.int32, context.int32], context.int32)
# func.basic_blocks.append("entry") do |builder|
#   builder.ret builder.add(func.params[0], func.params[1])
# end
# ```
class LLVMM::Context
  # Creates a new, owned context. Pass `dispose_on_finalize: false` to
  # prevent disposal when the wrapper is finalized.
  def self.new(*, dispose_on_finalize : Bool = true)
    new(LibLLVMM.create_context, dispose_on_finalize)
  end

  # Wraps an existing `LibLLVMM::ContextRef`. When *dispose_on_finalize* is
  # false (e.g. when wrapping LLVM's global context), the underlying context
  # is not disposed at finalize time.
  def initialize(@unwrap : LibLLVMM::ContextRef, @dispose_on_finalize = true)
    @disposed               = false
    @builders               = [] of LLVMM::Builder
    @diagnostic_handler     = nil
    @diagnostic_handler_box = Pointer(Void).null
  end

  # Installs a handler invoked with the severity and message of each
  # diagnostic emitted for this context. Only one handler is supported;
  # calling again replaces the previous one.
  def on_diagnostic(&handler : LLVMM::DiagnosticSeverity, String ->) : Nil
    @diagnostic_handler     = handler
    @diagnostic_handler_box = Box.box(handler)
    LibLLVMM.set_diagnostic_handler(self, ->(di : LibLLVMM::DiagnosticInfoRef, opaque : Void*) {
      callback = Box(Proc(LLVMM::DiagnosticSeverity, String, Void)).unbox(opaque)
      severity = LibLLVMM.get_diag_info_severity(di)
      message  = LLVMM.string_and_dispose(LibLLVMM.get_diag_info_description(di))
      callback.call(severity, message)
    }, @diagnostic_handler_box)
  end

  # Sets whether names of values are discarded (saves memory; LLVM does not
  # allow re-enabling names once discarded).
  def discard_value_names=(discard : Bool)
    LibLLVMM.set_discard_value_names(self, discard)
    discard
  end

  # Whether names of values are discarded in this context.
  def discard_value_names? : Bool
    LibLLVMM.should_discard_value_names(self) != 0
  end

  # Creates a new module owned by this context.
  def new_module(name : String) : Module
    Module.new(LibLLVMM.module_create_with_name_in_context(name, self), self)
  end

  # Creates a new instruction builder. The context keeps a reference and
  # disposes the builder when the context is finalized.
  def new_builder : Builder
    # builder = Builder.new(LibLLVMM.create_builder_in_context(self), self)
    builder = Builder.new(LibLLVMM.create_builder_in_context(self))
    @builders << builder
    builder
  end

  # The `void` type.
  def void : Type
    Type.new LibLLVMM.void_type_in_context(self)
  end

  # The `i1` (boolean) integer type.
  def int1 : Type
    Type.new LibLLVMM.int1_type_in_context(self)
  end

  # The `i8` integer type.
  def int8 : Type
    Type.new LibLLVMM.int8_type_in_context(self)
  end

  # The `i16` integer type.
  def int16 : Type
    Type.new LibLLVMM.int16_type_in_context(self)
  end

  # The `i32` integer type.
  def int32 : Type
    Type.new LibLLVMM.int32_type_in_context(self)
  end

  # The `i64` integer type.
  def int64 : Type
    Type.new LibLLVMM.int64_type_in_context(self)
  end

  # The `i128` integer type.
  def int128 : Type
    Type.new LibLLVMM.int128_type_in_context(self)
  end

  # The integer type with an arbitrary bit width.
  def int(bits : Int) : Type
    Type.new LibLLVMM.int_type_in_context(self, bits)
  end

  # The `half` (16-bit) floating-point type.
  def half : Type
    Type.new LibLLVMM.half_type_in_context(self)
  end

  # The `bfloat` (16-bit brain) floating-point type.
  def bfloat : Type
    Type.new LibLLVMM.bfloat_type_in_context(self)
  end

  # The `float` (32-bit) floating-point type.
  def float : Type
    Type.new LibLLVMM.float_type_in_context(self)
  end

  # The `double` (64-bit) floating-point type.
  def double : Type
    Type.new LibLLVMM.double_type_in_context(self)
  end

  # The `x86_fp80` (80-bit x87) floating-point type.
  def x86_fp80 : Type
    Type.new LibLLVMM.x86_fp80_type_in_context(self)
  end

  # The `fp128` (128-bit IEEE) floating-point type.
  def fp128 : Type
    Type.new LibLLVMM.fp128_type_in_context(self)
  end

  # The `ppc_fp128` (PowerPC double-double) floating-point type.
  def ppc_fp128 : Type
    Type.new LibLLVMM.ppc_fp128_type_in_context(self)
  end

  # The `x86_amx` (AMX tile) type.
  def x86_amx : Type
    Type.new LibLLVMM.x86_amx_type_in_context(self)
  end

  # The `token` type.
  def token : Type
    Type.new LibLLVMM.token_type_in_context(self)
  end

  # The opaque pointer type in the given address space.
  def pointer(address_space = 0) : Type
    Type.new LibLLVMM.pointer_type_in_context(self, address_space)
  end

  # Same as `pointer`: with opaque pointers there is no distinct
  # void-pointer type.
  def void_pointer(address_space = 0) : Type
    pointer(address_space)
  end

  # Creates a named (identified) struct type. The block receives the struct
  # type before its body is set — allowing self-referential types — and must
  # return the element types as an `Array(LLVMM::Type)`.
  def struct(name : String, packed = false, &) : Type
    llvm_struct   = LibLLVMM.struct_create_named(self, name)
    the_struct    = Type.new llvm_struct
    element_types = (yield the_struct).as(Array(LLVMM::Type))
    LibLLVMM.struct_set_body(llvm_struct, (element_types.to_unsafe.as(LibLLVMM::TypeRef*)), element_types.size, packed ? 1 : 0)
    the_struct
  end

  # Creates a struct type with the given element types. Without a *name* this
  # is a literal (anonymously identified) struct; with a *name* it is a named
  # (identified) struct.
  def struct(element_types : Array(LLVMM::Type), name = nil, packed = false) : Type
    if name
      self.struct(name, packed) { element_types }
    else
      Type.new LibLLVMM.struct_type_in_context(self, (element_types.to_unsafe.as(LibLLVMM::TypeRef*)), element_types.size, packed ? 1 : 0)
    end
  end

  # A constant byte-array holding *string*, including a trailing NUL.
  def const_string(string : String) : Value
    const_bytes(string.unsafe_byte_slice(0, string.bytesize + 1))
  end

  # A constant byte-array holding exactly *bytes* (no terminator is added).
  def const_bytes(bytes : Bytes) : Value
    {% if LibLLVMM::IS_LT_190 %}
      Value.new LibLLVMM.const_string_in_context(self, bytes, bytes.size, 1)
    {% else %}
      Value.new LibLLVMM.const_string_in_context2(self, bytes, bytes.size, 1)
    {% end %}
  end

  # A constant struct composed of *values*.
  def const_struct(values : Array(LLVMM::Value), packed = false) : Value
    Value.new LibLLVMM.const_struct_in_context(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size, packed ? 1 : 0)
  end

  # A constant vector composed of *values*.
  def const_vector(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_vector((values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  # A constant pointer-authentication (ptrauth) pointer. Requires LLVM 19+;
  # raises `NotImplementedError` on older versions (`IS_LT_190`).
  def const_ptr_auth(ptr, key, disc, addr_disc) : Value
    {% if LibLLVMM::IS_LT_190 %}
      raise NotImplementedError.new("LLVMM::Context#const_ptr_auth")
    {% else %}
      Value.new LibLLVMM.constant_ptr_auth(ptr, key, disc, addr_disc)
    {% end %}
  end

  # A metadata string node.
  def md_string(value : String) : Value
    LLVMM::Value.new LibLLVMM.md_string_in_context2(self, value, value.bytesize)
  end

  # A metadata node composed of the given metadata operands.
  def md_node(mds : Array(LibLLVMM::MetadataRef)) : LibLLVMM::MetadataRef
    LibLLVMM.md_node_in_context2(self, mds.to_unsafe, mds.size)
  end

  # A metadata node composed of the given values (converted to metadata).
  def md_node(values : Array(Value)) : LibLLVMM::MetadataRef
    md_node(values.map { |value| LibLLVMM.value_as_metadata(value) })
  end

  # A temporary metadata node, e.g. for forward references while building
  # debug info. Must be resolved (see `Metadata#dispose_temporary`) before
  # the module is verified or materialized.
  def temporary_md_node(mds : Array(LibLLVMM::MetadataRef)) : LibLLVMM::MetadataRef
    LibLLVMM.temporary_md_node(self, mds.to_unsafe, mds.size)
  end

  # The `metadata` type.
  def metadata_type : Type
    Type.new LibLLVMM.metadata_type_in_context(self)
  end

  # Parses textual LLVM IR from *buf* and returns the resulting module, owned
  # by this context. Raises with LLVM's diagnostic on a parse error. LLVM
  # consumes the buffer (ownership is transferred, as with
  # `MemoryBuffer#take_ownership`), so this raises if the buffer was already
  # consumed.
  def parse_ir(buf : MemoryBuffer)
    buf.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    ret = LibLLVMM.parse_ir_in_context(self, buf, out mod, out msg)
    if ret != 0 && msg
      raise LLVMM.string_and_dispose(msg)
    end
    Module.new(mod, self)
  end

  # Two contexts are equal if they wrap the same underlying `LLVMContext`.
  def ==(other : self)
    @unwrap == other.@unwrap
  end

  # The underlying `LibLLVMM::ContextRef`.
  def to_unsafe
    @unwrap
  end

  # Marks the context as owned elsewhere, disabling disposal at finalize
  # time (used when handing the context to `Orc::ThreadSafeContext`). Yields
  # if ownership was already taken, letting the caller reject a double
  # handoff.
  def take_ownership(&)
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end

  # Disposes the builders created by `new_builder`, then the context itself
  # unless disposal was disabled (see `take_ownership`).
  def finalize
    return if @disposed
    @disposed = true

    @builders.each &.dispose

    LibLLVMM.dispose_context(self) if @dispose_on_finalize
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # @@info = {} of UInt64 => String

  # def self.register(context : Context, name : String)
  #   @@info[context.@unwrap.address] = name
  # end

  # def self.lookup(context : Context)
  #   @@info[context.@unwrap.address]? || "global"
  # end

  # def self.wrong(expected, got, msg)
  #   raise "#{msg} (expected #{lookup(expected)}, got #{lookup(got)})"
  # end
end
