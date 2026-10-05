# src/llvmm/orc/thread_safe_module.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ThreadSafeModule
  protected def initialize(@unwrap : LibLLVMM::OrcThreadSafeModuleRef, @dispose_on_finalize = true)
  end

  def self.new(llvm_mod : LLVMM::Module, ts_ctx : ThreadSafeContext)
    llvm_mod.take_ownership { raise "Failed to take ownership of LLVMM::Module" }
    new(LibLLVMM.orc_create_new_thread_safe_module(llvm_mod, ts_ctx))
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LibLLVMM.orc_dispose_thread_safe_module(self)
    @unwrap = LibLLVMM::OrcThreadSafeModuleRef.null
  end

  def finalize
    if @dispose_on_finalize && @unwrap
      dispose
    end
  end

  def with_module_do(&block : LLVMM::Module ->) : Nil
    boxed = Box.box(block)
    LLVMM.assert LibLLVMM.orc_thread_safe_module_with_module_do(self, ->(ctx : Void*, m : LibLLVMM::ModuleRef) {
      callback = Box(Proc(LLVMM::Module, Nil)).unbox(ctx)
      context  = LLVMM::Context.new(LibLLVMM.get_module_context(m), dispose_on_finalize: false)
      callback.call(LLVMM::Module.new(m, context))
      Pointer(Void).null.as(LibLLVMM::ErrorRef)
    }, boxed)
  end

  def take_ownership(&) : Nil
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end
end
