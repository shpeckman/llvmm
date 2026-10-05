# src/llvmm/jit_compiler.cr
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

  def self.new(mod, &)
    jit = new(mod)
    yield jit ensure jit.dispose
  end

  def run_function(func, context : Context)
    ret = LibLLVMM.run_function(self, func, 0, nil)
    GenericValue.new(ret, context)
  end

  def get_pointer_to_global(value)
    LibLLVMM.get_pointer_to_global(self, value)
  end

  def function_address(name : String) : Void*
    Pointer(Void).new(LibLLVMM.get_function_address(self, name.check_no_null_byte))
  end

  def add_symbol(name : String, address : Void*) : Nil
    LibLLVMM.add_symbol(name.check_no_null_byte, address)
  end

  def to_unsafe
    @unwrap
  end

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
