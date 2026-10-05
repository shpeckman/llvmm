# src/llvmm/pass_builder_options.cr
class LLVMM::PassBuilderOptions
  def initialize
    @options  = LibLLVMM.create_pass_builder_options
    @disposed = false
  end

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

  def finalize
    return if @disposed
    @disposed = true

    LibLLVMM.dispose_pass_builder_options(self)
  end

  def set_inliner_threshold(threshold : Int)
    LibLLVMM.pass_builder_options_set_inliner_threshold(self, threshold)
  end

  {% unless LibLLVMM::IS_LT_200 %}
    def set_aa_pipeline(aa_pipeline : String)
      LibLLVMM.pass_builder_options_set_aa_pipeline(self, aa_pipeline)
    end
  {% end %}

  def set_loop_unrolling(enabled : Bool)
    LibLLVMM.pass_builder_options_set_loop_unrolling(self, enabled)
  end

  def set_loop_vectorization(enabled : Bool)
    LibLLVMM.pass_builder_options_set_loop_vectorization(self, enabled)
  end

  def set_slp_vectorization(enabled : Bool)
    LibLLVMM.pass_builder_options_set_slp_vectorization(self, enabled)
  end
end
