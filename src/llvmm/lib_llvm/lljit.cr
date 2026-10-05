# src/llvmm/lib_llvm/lljit.cr
lib LibLLVMM
  alias OrcLLJITBuilderRef = Void*
  alias OrcLLJITRef = Void*
  alias OrcLLJITBuilderObjectLinkingLayerCreatorFunction = Void*, OrcExecutionSessionRef, Char* -> OrcObjectLayerRef

  fun orc_create_lljit_builder = LLVMOrcCreateLLJITBuilder : OrcLLJITBuilderRef
  fun orc_dispose_lljit_builder = LLVMOrcDisposeLLJITBuilder(builder : OrcLLJITBuilderRef)
  fun orc_lljit_builder_set_jit_target_machine_builder = LLVMOrcLLJITBuilderSetJITTargetMachineBuilder(builder : OrcLLJITBuilderRef, jtmb : OrcJITTargetMachineBuilderRef)
  fun orc_lljit_builder_set_object_linking_layer_creator = LLVMOrcLLJITBuilderSetObjectLinkingLayerCreator(builder : OrcLLJITBuilderRef, f : OrcLLJITBuilderObjectLinkingLayerCreatorFunction, ctx : Void*)

  fun orc_create_lljit = LLVMOrcCreateLLJIT(result : OrcLLJITRef*, builder : OrcLLJITBuilderRef) : ErrorRef
  fun orc_dispose_lljit = LLVMOrcDisposeLLJIT(j : OrcLLJITRef) : ErrorRef

  fun orc_lljit_get_main_jit_dylib = LLVMOrcLLJITGetMainJITDylib(j : OrcLLJITRef) : OrcJITDylibRef
  fun orc_lljit_get_global_prefix = LLVMOrcLLJITGetGlobalPrefix(j : OrcLLJITRef) : Char
  fun orc_lljit_get_execution_session = LLVMOrcLLJITGetExecutionSession(j : OrcLLJITRef) : OrcExecutionSessionRef
  fun orc_lljit_get_triple_string = LLVMOrcLLJITGetTripleString(j : OrcLLJITRef) : Char*
  fun orc_lljit_get_data_layout_str = LLVMOrcLLJITGetDataLayoutStr(j : OrcLLJITRef) : Char*
  fun orc_lljit_mangle_and_intern = LLVMOrcLLJITMangleAndIntern(j : OrcLLJITRef, unmangled_name : Char*) : OrcSymbolStringPoolEntryRef
  fun orc_lljit_get_obj_linking_layer = LLVMOrcLLJITGetObjLinkingLayer(j : OrcLLJITRef) : OrcObjectLayerRef
  fun orc_lljit_get_obj_transform_layer = LLVMOrcLLJITGetObjTransformLayer(j : OrcLLJITRef) : OrcObjectTransformLayerRef
  fun orc_lljit_get_ir_transform_layer = LLVMOrcLLJITGetIRTransformLayer(j : OrcLLJITRef) : OrcIRTransformLayerRef
  fun orc_lljit_add_llvm_ir_module = LLVMOrcLLJITAddLLVMIRModule(j : OrcLLJITRef, jd : OrcJITDylibRef, tsm : OrcThreadSafeModuleRef) : ErrorRef
  fun orc_lljit_add_llvm_ir_module_with_rt = LLVMOrcLLJITAddLLVMIRModuleWithRT(j : OrcLLJITRef, rt : OrcResourceTrackerRef, tsm : OrcThreadSafeModuleRef) : ErrorRef
  fun orc_lljit_add_object_file = LLVMOrcLLJITAddObjectFile(j : OrcLLJITRef, jd : OrcJITDylibRef, obj_buffer : MemoryBufferRef) : ErrorRef
  fun orc_lljit_add_object_file_with_rt = LLVMOrcLLJITAddObjectFileWithRT(j : OrcLLJITRef, rt : OrcResourceTrackerRef, obj_buffer : MemoryBufferRef) : ErrorRef
  fun orc_lljit_lookup = LLVMOrcLLJITLookup(j : OrcLLJITRef, result : OrcExecutorAddress*, name : Char*) : ErrorRef
end
