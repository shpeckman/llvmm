# src/llvmm/lib_llvm/transforms/pass_builder.cr
require "../target_machine"
require "../types"

lib LibLLVMM
  type PassBuilderOptionsRef = Void*

  fun run_passes = LLVMRunPasses(m : ModuleRef, passes : Char*, tm : TargetMachineRef, options : PassBuilderOptionsRef) : ErrorRef
  {% unless LibLLVMM::IS_LT_200 %}
    fun run_passes_on_function = LLVMRunPassesOnFunction(f : ValueRef, passes : Char*, tm : TargetMachineRef, options : PassBuilderOptionsRef) : ErrorRef
  {% end %}

  fun create_pass_builder_options = LLVMCreatePassBuilderOptions : PassBuilderOptionsRef
  fun dispose_pass_builder_options = LLVMDisposePassBuilderOptions(options : PassBuilderOptionsRef)
  fun pass_builder_options_set_inliner_threshold = LLVMPassBuilderOptionsSetInlinerThreshold(PassBuilderOptionsRef, Int)
  {% unless LibLLVMM::IS_LT_200 %}
    fun pass_builder_options_set_aa_pipeline = LLVMPassBuilderOptionsSetAAPipeline(options : PassBuilderOptionsRef, aa_pipeline : Char*)
  {% end %}
  fun pass_builder_options_set_loop_unrolling = LLVMPassBuilderOptionsSetLoopUnrolling(PassBuilderOptionsRef, Bool)
  fun pass_builder_options_set_loop_vectorization = LLVMPassBuilderOptionsSetLoopVectorization(PassBuilderOptionsRef, Bool)
  fun pass_builder_options_set_slp_vectorization = LLVMPassBuilderOptionsSetSLPVectorization(PassBuilderOptionsRef, Bool)
end
