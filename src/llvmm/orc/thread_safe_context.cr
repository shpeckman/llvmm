# src/llvmm/orc/thread_safe_context.cr
# Wraps LLVM's ORCv2 `ThreadSafeContext`, a mutex-guarded wrapper around an
# `LLVMM::Context` that allows ORC to access LLVM IR from multiple threads.
#
# The wrapper owns the underlying context and everything built in it. It is
# disposed by the GC finalizer, or eagerly with `dispose` (dispose after the
# JIT using it has been disposed).
#
# ```
# context = LLVMM::Context.new
# ts_ctx = LLVMM::Orc::ThreadSafeContext.new(context) # LLVM >= 21
# mod = context.new_module("m")
# tsm = LLVMM::Orc::ThreadSafeModule.new(mod, ts_ctx)
# lljit.add_llvm_ir_module(lljit.main_jit_dylib, tsm)
# ```
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ThreadSafeContext
  protected def initialize(@unwrap : LibLLVMM::OrcThreadSafeContextRef)
  end

  # Creates a thread-safe context wrapping a fresh `LLVMM::Context`.
  def self.new
    new(LibLLVMM.orc_create_new_thread_safe_context)
  end

  # Creates a thread-safe context wrapping *ctx*, taking ownership of it: the
  # passed `LLVMM::Context` wrapper no longer disposes the context and must
  # not be disposed manually (it may still be used to build IR). Raises if
  # ownership of *ctx* has already been taken.
  #
  # This constructor is only available with LLVMM 21 and above.
  def self.new(ctx : LLVMM::Context)
    {% if LibLLVMM.has_method?(:orc_create_new_thread_safe_context_from_llvm_context) %}
      ctx.take_ownership { raise "Failed to take ownership of LLVMM::Context" }
      new(LibLLVMM.orc_create_new_thread_safe_context_from_llvm_context(ctx))
    {% else %}
      raise NotImplementedError.new("LLVMM::Orc::ThreadSafeContext.new(LLVMM::Context)")
    {% end %}
  end

  def to_unsafe
    @unwrap
  end

  # Disposes the thread-safe context and the context it wraps. Call only after
  # the JIT and all modules using this context are done with it. After
  # disposal the wrapper is inert and the finalizer becomes a no-op.
  def dispose : Nil
    LibLLVMM.orc_dispose_thread_safe_context(self)
    @unwrap = LibLLVMM::OrcThreadSafeContextRef.null
  end

  def finalize
    if @unwrap
      dispose
    end
  end

  # Returns the wrapped `LLVMM::Context`. The returned context is borrowed:
  # it does not dispose the context and becomes invalid once this thread-safe
  # context is disposed.
  #
  # Only available with LLVMM 20 and below; raises `NotImplementedError` on
  # LLVMM 21 and above, where the context is supplied to the constructor
  # instead.
  def context : LLVMM::Context
    {% if LibLLVMM.has_method?(:orc_thread_safe_context_get_context) %}
      LLVMM::Context.new(LibLLVMM.orc_thread_safe_context_get_context(self), false)
    {% else %}
      raise NotImplementedError.new("LLVMM::Orc::ThreadSafeContext#context")
    {% end %}
  end
end
