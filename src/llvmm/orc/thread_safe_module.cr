# src/llvmm/orc/thread_safe_module.cr
# Wraps LLVM's ORCv2 `ThreadSafeModule`, an `LLVMM::Module` paired with a
# `ThreadSafeContext` so it can be handed to ORC safely.
#
# Construction takes ownership of the passed `LLVMM::Module`: the module
# wrapper no longer disposes the module. This wrapper in turn disposes the
# module (via its context) on finalization, unless ownership is taken first —
# ORC takes ownership when the module is added to a JIT, e.g. via
# `LLJIT#add_llvm_ir_module`, so no manual disposal is needed in the usual
# flow.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ThreadSafeModule
  protected def initialize(@unwrap : LibLLVMM::OrcThreadSafeModuleRef, @dispose_on_finalize = true)
  end

  # Creates a thread-safe module from *llvm_mod* guarded by *ts_ctx*. Takes
  # ownership of *llvm_mod*; raises if the module's ownership has already been
  # taken.
  def self.new(llvm_mod : LLVMM::Module, ts_ctx : ThreadSafeContext)
    llvm_mod.take_ownership { raise "Failed to take ownership of LLVMM::Module" }
    new(LibLLVMM.orc_create_new_thread_safe_module(llvm_mod, ts_ctx))
  end

  def to_unsafe
    @unwrap
  end

  # Disposes the module. Normally unnecessary: the GC finalizer disposes it
  # unless ownership has been taken (e.g. by ORC after the module was added to
  # a JIT). After disposal the wrapped pointer is null.
  def dispose : Nil
    LibLLVMM.orc_dispose_thread_safe_module(self)
    @unwrap = LibLLVMM::OrcThreadSafeModuleRef.null
  end

  def finalize
    if @dispose_on_finalize && @unwrap
      dispose
    end
  end

  # Yields the underlying `LLVMM::Module` while holding the context lock. The
  # yielded module is borrowed and must not escape the block or be disposed.
  # Raises `LLVMM::Error` if the operation fails.
  def with_module_do(&block : LLVMM::Module ->) : Nil
    boxed = Box.box(block)
    LLVMM.assert LibLLVMM.orc_thread_safe_module_with_module_do(self, ->(ctx : Void*, m : LibLLVMM::ModuleRef) {
      callback = Box(Proc(LLVMM::Module, Nil)).unbox(ctx)
      context  = LLVMM::Context.new(LibLLVMM.get_module_context(m), dispose_on_finalize: false)
      callback.call(LLVMM::Module.new(m, context))
      Pointer(Void).null.as(LibLLVMM::ErrorRef)
    }, boxed)
  end

  # Marks ownership of the underlying module as taken, disabling disposal by
  # the finalizer. Yields without taking ownership if ownership was already
  # taken before — callers typically pass a block that raises or handles the
  # conflict.
  def take_ownership(&) : Nil
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end
end
