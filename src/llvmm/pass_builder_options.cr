# src/llvmm/pass_builder_options.cr
# Options controlling LLVM's new pass manager when running optimization
# pipelines (wraps `LLVMPassBuilderOptionsRef`).
#
# Prefer the block form of `.new`, which guarantees disposal:
#
# ```
# LLVMM::PassBuilderOptions.new do |options|
#   options.set_loop_vectorization(true)
# end
# ```
#
# Without the block form the options are disposed by the GC finalizer.
# Disposal is idempotent.
class LLVMM::PassBuilderOptions
  def initialize
    @options = LibLLVMM.create_pass_builder_options
    @disposed = false
  end

  # Yields a fresh options object and disposes it when the block returns,
  # even if the block raises.
  def self.new(&)
    options = new
    begin
      yield options
    ensure
      options.finalize
    end
  end

  def to_unsafe
    @options
  end

  # Disposes the options; called automatically by the block form of `.new`
  # and by the GC. Safe to trigger more than once.
  def finalize
    return if @disposed
    @disposed = true

    LibLLVMM.dispose_pass_builder_options(self)
  end

  # Sets the inlining threshold; higher values inline more aggressively.
  def set_inliner_threshold(threshold : Int)
    LibLLVMM.pass_builder_options_set_inliner_threshold(self, threshold)
  end

  {% unless LibLLVMM::IS_LT_200 %}
    # Sets the alias-analysis pipeline to use, e.g. `"basic-aa"`.
    #
    # Requires LLVM 20 or later.
    def set_aa_pipeline(aa_pipeline : String)
      LibLLVMM.pass_builder_options_set_aa_pipeline(self, aa_pipeline)
    end
  {% end %}

  # Enables or disables loop unrolling.
  def set_loop_unrolling(enabled : Bool)
    LibLLVMM.pass_builder_options_set_loop_unrolling(self, enabled)
  end

  # Enables or disables loop vectorization.
  def set_loop_vectorization(enabled : Bool)
    LibLLVMM.pass_builder_options_set_loop_vectorization(self, enabled)
  end

  # Enables or disables SLP (superword-level parallelism) vectorization.
  def set_slp_vectorization(enabled : Bool)
    LibLLVMM.pass_builder_options_set_slp_vectorization(self, enabled)
  end
end
