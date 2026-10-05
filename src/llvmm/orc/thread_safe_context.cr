# src/llvmm/orc/thread_safe_context.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ThreadSafeContext
  protected def initialize(@unwrap : LibLLVMM::OrcThreadSafeContextRef)
  end

  def self.new
    new(LibLLVMM.orc_create_new_thread_safe_context)
  end

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

  def dispose : Nil
    LibLLVMM.orc_dispose_thread_safe_context(self)
    @unwrap = LibLLVMM::OrcThreadSafeContextRef.null
  end

  def finalize
    if @unwrap
      dispose
    end
  end

  def context : LLVMM::Context
    {% if LibLLVMM.has_method?(:orc_thread_safe_context_get_context) %}
      LLVMM::Context.new(LibLLVMM.orc_thread_safe_context_get_context(self), false)
    {% else %}
      raise NotImplementedError.new("LLVMM::Orc::ThreadSafeContext#context")
    {% end %}
  end
end
