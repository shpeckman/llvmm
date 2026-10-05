# src/llvmm/jit_compiler.cr

# JIT compiler based on LLVM's legacy MCJIT ExecutionEngine API.
#
# This is the older, pre-ORC JIT stack; `LLVMM::JIT` is the higher-level ORCv2-based
# alternative. A typical use is compiling a module and calling its functions through
# a Crystal `Proc` built from `#function_address`:
#
# ```
# LLVMM::JITCompiler.new(mod) do |jit|
#   add = Proc(Int32, Int32, Int32).new(jit.function_address("add"), Pointer(Void).null)
#   add.call(19, 23) # => 42
# end
# ```
#
# Construction takes ownership of the given `LLVMM::Module` (see
# `LLVMM::Module#take_ownership`): the module must not back another JIT compiler, and
# it is disposed together with the engine. The engine is created with the default
# MCJIT options (no optimization); GlobalISel is disabled on its target machine to
# work around LLVM issues with zero-sized types (crystal-lang/crystal#9297).
class LLVMM::JITCompiler
  def initialize(mod)
    # JIT compilers own an LLVMM::Module, and when they are disposed the module is disposed,
    # so we must prevent the module from being dispose when the GC will want to free it.
    mod.take_ownership { raise "Can't create two JIT compilers for the same module" }

    # if LibLLVMM.create_jit_compiler_for_module(out @unwrap, mod, 3, out error) != 0
    if LibLLVMM.create_mc_jit_compiler_for_module(out @unwrap, mod, nil, 0, out error) != 0
      raise LLVMM.string_and_dispose(error)
    end

    # FIXME: We need to disable global isel until https://reviews.llvm.org/D80898 is released,
    # or we fixed generating values for 0 sized types.
    # When removing this, also remove it from the ABI specs and Crystal::Codegen::Target.
    # See https://github.com/crystal-lang/crystal/issues/9297#issuecomment-636512270
    # for background info
    target_machine = LibLLVMM.get_execution_engine_target_machine(@unwrap)
    LibLLVMM.set_target_machine_global_isel(target_machine, 0)

    @finalized = false
  end

  # Creates a JIT compiler and yields it, disposing it when the block returns.
  def self.new(mod, &)
    jit = new(mod)
    yield jit ensure jit.dispose
  end

  # Runs *func* with no arguments and returns its result as an
  # `LLVMM::GenericValue` tied to *context*.
  def run_function(func, context : Context)
    ret = LibLLVMM.run_function(self, func, 0, nil)
    GenericValue.new(ret, context)
  end

  # Returns a pointer to the JIT-compiled storage of the global variable *value*.
  def get_pointer_to_global(value)
    LibLLVMM.get_pointer_to_global(self, value)
  end

  # Returns the address of the compiled function *name*, or a null pointer if no
  # function with that name exists. The address is valid until the compiler is
  # disposed and can be wrapped in a Crystal `Proc`.
  def function_address(name : String) : Void*
    Pointer(Void).new(LibLLVMM.get_function_address(self, name.check_no_null_byte))
  end

  # Maps *name* to *address* so JIT'd code can resolve it. Wraps `LLVMAddSymbol`:
  # the mapping is process-global and visible to every execution engine in the
  # process, not scoped to this compiler.
  def add_symbol(name : String, address : Void*) : Nil
    LibLLVMM.add_symbol(name.check_no_null_byte, address)
  end

  def to_unsafe
    @unwrap
  end

  # Disposes the execution engine and the module it owns. Idempotent.
  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  def finalize
    return if @finalized
    LibLLVMM.dispose_execution_engine(@unwrap)
  end
end
