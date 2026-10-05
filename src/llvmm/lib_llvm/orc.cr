# src/llvmm/lib_llvm/orc.cr
lib LibLLVMM
  # OrcJITTargetAddress before LLVMM 13.0 (also an alias of UInt64)
  alias OrcExecutorAddress = UInt64
  alias OrcSymbolStringPoolRef = Void*
  alias OrcSymbolStringPoolEntryRef = Void*
  alias OrcJITDylibRef = Void*
  alias OrcDefinitionGeneratorRef = Void*
  alias OrcResourceTrackerRef = Void*
  alias OrcLookupStateRef = Void*
  alias OrcMaterializationResponsibilityRef = Void*
  alias OrcObjectLayerRef = Void*
  alias OrcIRTransformLayerRef = Void*
  alias OrcObjectTransformLayerRef = Void*
  alias OrcIndirectStubsManagerRef = Void*
  alias OrcLazyCallThroughManagerRef = Void*
  alias OrcDumpObjectsRef = Void*
  alias OrcSymbolPredicate = Void*, OrcSymbolStringPoolEntryRef -> Int
  alias OrcThreadSafeContextRef = Void*
  alias OrcThreadSafeModuleRef = Void*
  alias OrcJITTargetMachineBuilderRef = Void*
  alias OrcExecutionSessionRef = Void*
  alias OrcMaterializationUnitRef = Void*

  enum JITSymbolGenericFlags : UInt8
    None                           = 0
    Exported                       = 1
    Weak                           = 2
    Callable                       = 4
    MaterializationSideEffectsOnly = 8
  end

  enum OrcLookupKind
    Static
    DLSym
  end

  enum OrcJITDylibLookupFlags
    MatchExportedSymbolsOnly
    MatchAllSymbols
  end

  enum OrcSymbolLookupFlags
    RequiredSymbol
    WeaklyReferencedSymbol
  end

  struct JITSymbolFlags
    generic_flags : UInt8
    target_flags  : UInt8
  end

  struct OrcCSymbolFlagsMapPair
    name  : OrcSymbolStringPoolEntryRef
    flags : JITSymbolFlags
  end

  alias OrcCSymbolFlagsMapPairs = OrcCSymbolFlagsMapPair*

  struct OrcCSymbolMapPair
    name    : OrcSymbolStringPoolEntryRef
    address : UInt64
  end

  alias OrcCSymbolMapPairs = OrcCSymbolMapPair*

  struct OrcCSymbolAliasMapEntry
    name  : OrcSymbolStringPoolEntryRef
    flags : JITSymbolFlags
  end

  struct OrcCSymbolAliasMapPair
    name  : OrcSymbolStringPoolEntryRef
    entry : OrcCSymbolAliasMapEntry
  end

  alias OrcCSymbolAliasMapPairs = OrcCSymbolAliasMapPair*

  struct OrcCSymbolsList
    symbols : OrcSymbolStringPoolEntryRef*
    length  : SizeT
  end

  struct OrcCDependenceMapPair
    jd    : OrcJITDylibRef
    names : OrcCSymbolsList
  end

  alias OrcCDependenceMapPairs = OrcCDependenceMapPair*

  {% unless LibLLVMM::IS_LT_190 %}
    struct OrcCSymbolDependenceGroup
      symbols : OrcCSymbolsList
      dependencies : OrcCDependenceMapPairs
      num_dependencies : SizeT
    end
  {% end %}

  struct OrcCJITDylibSearchOrderElement
    jd              : OrcJITDylibRef
    jd_lookup_flags : OrcJITDylibLookupFlags
  end

  alias OrcCJITDylibSearchOrder = OrcCJITDylibSearchOrderElement*

  struct OrcCLookupSetElement
    name         : OrcSymbolStringPoolEntryRef
    lookup_flags : OrcSymbolLookupFlags
  end

  alias OrcCLookupSet = OrcCLookupSetElement*

  alias OrcErrorReporterFunction = Void*, ErrorRef ->
  alias OrcExecutionSessionLookupHandleResultFunction = ErrorRef, OrcCSymbolMapPairs, SizeT, Void* ->
  alias OrcCAPIDefinitionGeneratorTryToGenerateFunction = OrcDefinitionGeneratorRef, Void*, OrcLookupStateRef*, OrcLookupKind, OrcJITDylibRef, OrcJITDylibLookupFlags, OrcCLookupSet, SizeT -> ErrorRef
  alias OrcDisposeCAPIDefinitionGeneratorFunction = Void* ->
  alias OrcGenericIRModuleOperationFunction = Void*, ModuleRef -> ErrorRef
  alias OrcMaterializationUnitMaterializeFunction = Void*, OrcMaterializationResponsibilityRef ->
  alias OrcMaterializationUnitDiscardFunction = Void*, OrcJITDylibRef, OrcSymbolStringPoolEntryRef ->
  alias OrcMaterializationUnitDestroyFunction = Void* ->
  alias OrcIRTransformLayerTransformFunction = Void*, OrcThreadSafeModuleRef*, OrcMaterializationResponsibilityRef -> ErrorRef
  alias OrcObjectTransformLayerTransformFunction = Void*, MemoryBufferRef* -> ErrorRef

  fun orc_execution_session_set_error_reporter = LLVMOrcExecutionSessionSetErrorReporter(es : OrcExecutionSessionRef, report_error : OrcErrorReporterFunction, ctx : Void*)
  fun orc_execution_session_get_symbol_string_pool = LLVMOrcExecutionSessionGetSymbolStringPool(es : OrcExecutionSessionRef) : OrcSymbolStringPoolRef
  fun orc_symbol_string_pool_clear_dead_entries = LLVMOrcSymbolStringPoolClearDeadEntries(ssp : OrcSymbolStringPoolRef)
  fun orc_execution_session_intern = LLVMOrcExecutionSessionIntern(es : OrcExecutionSessionRef, name : Char*) : OrcSymbolStringPoolEntryRef
  fun orc_retain_symbol_string_pool_entry = LLVMOrcRetainSymbolStringPoolEntry(s : OrcSymbolStringPoolEntryRef)
  fun orc_release_symbol_string_pool_entry = LLVMOrcReleaseSymbolStringPoolEntry(s : OrcSymbolStringPoolEntryRef)
  fun orc_symbol_string_pool_entry_str = LLVMOrcSymbolStringPoolEntryStr(s : OrcSymbolStringPoolEntryRef) : Char*
  fun orc_execution_session_lookup = LLVMOrcExecutionSessionLookup(es : OrcExecutionSessionRef, k : OrcLookupKind, search_order : OrcCJITDylibSearchOrder, search_order_size : SizeT, symbols : OrcCLookupSet, symbols_size : SizeT, handle_result : OrcExecutionSessionLookupHandleResultFunction, ctx : Void*)

  fun orc_release_resource_tracker = LLVMOrcReleaseResourceTracker(rt : OrcResourceTrackerRef)
  fun orc_resource_tracker_transfer_to = LLVMOrcResourceTrackerTransferTo(src_rt : OrcResourceTrackerRef, dst_rt : OrcResourceTrackerRef)
  fun orc_resource_tracker_remove = LLVMOrcResourceTrackerRemove(rt : OrcResourceTrackerRef) : ErrorRef

  fun orc_dispose_definition_generator = LLVMOrcDisposeDefinitionGenerator(dg : OrcDefinitionGeneratorRef)
  fun orc_dispose_materialization_unit = LLVMOrcDisposeMaterializationUnit(mu : OrcMaterializationUnitRef)
  fun orc_create_custom_materialization_unit = LLVMOrcCreateCustomMaterializationUnit(name : Char*, ctx : Void*, syms : OrcCSymbolFlagsMapPairs, num_syms : SizeT, init_sym : OrcSymbolStringPoolEntryRef, materialize : OrcMaterializationUnitMaterializeFunction, discard : OrcMaterializationUnitDiscardFunction, destroy : OrcMaterializationUnitDestroyFunction) : OrcMaterializationUnitRef
  fun orc_absolute_symbols = LLVMOrcAbsoluteSymbols(syms : OrcCSymbolMapPairs, num_pairs : SizeT) : OrcMaterializationUnitRef
  fun orc_lazy_reexports = LLVMOrcLazyReexports(lctm : OrcLazyCallThroughManagerRef, ism : OrcIndirectStubsManagerRef, source_ref : OrcJITDylibRef, callable_aliases : OrcCSymbolAliasMapPairs, num_pairs : SizeT) : OrcMaterializationUnitRef

  fun orc_dispose_materialization_responsibility = LLVMOrcDisposeMaterializationResponsibility(mr : OrcMaterializationResponsibilityRef)
  fun orc_materialization_responsibility_get_target_dylib = LLVMOrcMaterializationResponsibilityGetTargetDylib(mr : OrcMaterializationResponsibilityRef) : OrcJITDylibRef
  fun orc_materialization_responsibility_get_execution_session = LLVMOrcMaterializationResponsibilityGetExecutionSession(mr : OrcMaterializationResponsibilityRef) : OrcExecutionSessionRef
  fun orc_materialization_responsibility_get_symbols = LLVMOrcMaterializationResponsibilityGetSymbols(mr : OrcMaterializationResponsibilityRef, num_pairs : SizeT*) : OrcCSymbolFlagsMapPairs
  fun orc_dispose_c_symbol_flags_map = LLVMOrcDisposeCSymbolFlagsMap(pairs : OrcCSymbolFlagsMapPairs)
  fun orc_materialization_responsibility_get_initializer_symbol = LLVMOrcMaterializationResponsibilityGetInitializerSymbol(mr : OrcMaterializationResponsibilityRef) : OrcSymbolStringPoolEntryRef
  fun orc_materialization_responsibility_get_requested_symbols = LLVMOrcMaterializationResponsibilityGetRequestedSymbols(mr : OrcMaterializationResponsibilityRef, num_symbols : SizeT*) : OrcSymbolStringPoolEntryRef*
  fun orc_dispose_symbols = LLVMOrcDisposeSymbols(symbols : OrcSymbolStringPoolEntryRef*)
  fun orc_materialization_responsibility_notify_resolved = LLVMOrcMaterializationResponsibilityNotifyResolved(mr : OrcMaterializationResponsibilityRef, symbols : OrcCSymbolMapPairs, num_pairs : SizeT) : ErrorRef
  {% if LibLLVMM::IS_LT_190 %}
    fun orc_materialization_responsibility_notify_emitted = LLVMOrcMaterializationResponsibilityNotifyEmitted(mr : OrcMaterializationResponsibilityRef) : ErrorRef
    fun orc_materialization_responsibility_add_dependencies = LLVMOrcMaterializationResponsibilityAddDependencies(mr : OrcMaterializationResponsibilityRef, name : OrcSymbolStringPoolEntryRef, dependencies : OrcCDependenceMapPairs, num_pairs : SizeT)
  {% else %}
    fun orc_materialization_responsibility_notify_emitted = LLVMOrcMaterializationResponsibilityNotifyEmitted(mr : OrcMaterializationResponsibilityRef, symbol_dep_groups : OrcCSymbolDependenceGroup*, num_symbol_dep_groups : SizeT) : ErrorRef
  {% end %}
  fun orc_materialization_responsibility_define_materializing = LLVMOrcMaterializationResponsibilityDefineMaterializing(mr : OrcMaterializationResponsibilityRef, pairs : OrcCSymbolFlagsMapPairs, num_pairs : SizeT) : ErrorRef
  fun orc_materialization_responsibility_fail_materialization = LLVMOrcMaterializationResponsibilityFailMaterialization(mr : OrcMaterializationResponsibilityRef)
  fun orc_materialization_responsibility_replace = LLVMOrcMaterializationResponsibilityReplace(mr : OrcMaterializationResponsibilityRef, mu : OrcMaterializationUnitRef) : ErrorRef
  fun orc_materialization_responsibility_delegate = LLVMOrcMaterializationResponsibilityDelegate(mr : OrcMaterializationResponsibilityRef, symbols : OrcSymbolStringPoolEntryRef*, num_symbols : SizeT, result : OrcMaterializationResponsibilityRef*) : ErrorRef

  fun orc_execution_session_create_bare_jit_dylib = LLVMOrcExecutionSessionCreateBareJITDylib(es : OrcExecutionSessionRef, name : Char*) : OrcJITDylibRef
  fun orc_execution_session_create_jit_dylib = LLVMOrcExecutionSessionCreateJITDylib(es : OrcExecutionSessionRef, result : OrcJITDylibRef*, name : Char*) : ErrorRef
  fun orc_execution_session_get_jit_dylib_by_name = LLVMOrcExecutionSessionGetJITDylibByName(es : OrcExecutionSessionRef, name : Char*) : OrcJITDylibRef
  fun orc_jit_dylib_create_resource_tracker = LLVMOrcJITDylibCreateResourceTracker(jd : OrcJITDylibRef) : OrcResourceTrackerRef
  fun orc_jit_dylib_get_default_resource_tracker = LLVMOrcJITDylibGetDefaultResourceTracker(jd : OrcJITDylibRef) : OrcResourceTrackerRef
  fun orc_jit_dylib_define = LLVMOrcJITDylibDefine(jd : OrcJITDylibRef, mu : OrcMaterializationUnitRef) : ErrorRef
  fun orc_jit_dylib_clear = LLVMOrcJITDylibClear(jd : OrcJITDylibRef) : ErrorRef
  fun orc_jit_dylib_add_generator = LLVMOrcJITDylibAddGenerator(jd : OrcJITDylibRef, dg : OrcDefinitionGeneratorRef)

  fun orc_create_custom_capi_definition_generator = LLVMOrcCreateCustomCAPIDefinitionGenerator(f : OrcCAPIDefinitionGeneratorTryToGenerateFunction, ctx : Void*, dispose : OrcDisposeCAPIDefinitionGeneratorFunction) : OrcDefinitionGeneratorRef
  fun orc_lookup_state_continue_lookup = LLVMOrcLookupStateContinueLookup(s : OrcLookupStateRef, err : ErrorRef)

  fun orc_create_dynamic_library_search_generator_for_process = LLVMOrcCreateDynamicLibrarySearchGeneratorForProcess(
    result : OrcDefinitionGeneratorRef*, global_prefx : Char,
    filter : OrcSymbolPredicate, filter_ctx : Void*,
  ) : ErrorRef

  fun orc_create_dynamic_library_search_generator_for_path = LLVMOrcCreateDynamicLibrarySearchGeneratorForPath(result : OrcDefinitionGeneratorRef*, file_name : Char*, global_prefix : Char, filter : OrcSymbolPredicate, filter_ctx : Void*) : ErrorRef
  {% unless LibLLVMM::IS_LT_210 %}
    fun orc_create_static_library_search_generator_for_path = LLVMOrcCreateStaticLibrarySearchGeneratorForPath(result : OrcDefinitionGeneratorRef*, obj_layer : OrcObjectLayerRef, file_name : Char*) : ErrorRef
  {% end %}

  fun orc_create_new_thread_safe_context = LLVMOrcCreateNewThreadSafeContext : OrcThreadSafeContextRef
  {% if LibLLVMM::IS_LT_210 %}
    fun orc_thread_safe_context_get_context = LLVMOrcThreadSafeContextGetContext(ts_ctx : OrcThreadSafeContextRef) : ContextRef
  {% else %}
    fun orc_create_new_thread_safe_context_from_llvm_context = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(ctx : ContextRef) : OrcThreadSafeContextRef
  {% end %}
  fun orc_dispose_thread_safe_context = LLVMOrcDisposeThreadSafeContext(ts_ctx : OrcThreadSafeContextRef)

  fun orc_create_new_thread_safe_module = LLVMOrcCreateNewThreadSafeModule(m : ModuleRef, ts_ctx : OrcThreadSafeContextRef) : OrcThreadSafeModuleRef
  fun orc_dispose_thread_safe_module = LLVMOrcDisposeThreadSafeModule(tsm : OrcThreadSafeModuleRef)
  fun orc_thread_safe_module_with_module_do = LLVMOrcThreadSafeModuleWithModuleDo(tsm : OrcThreadSafeModuleRef, f : OrcGenericIRModuleOperationFunction, ctx : Void*) : ErrorRef

  fun orc_jit_target_machine_builder_detect_host = LLVMOrcJITTargetMachineBuilderDetectHost(result : OrcJITTargetMachineBuilderRef*) : ErrorRef
  fun orc_jit_target_machine_builder_create_from_target_machine = LLVMOrcJITTargetMachineBuilderCreateFromTargetMachine(tm : TargetMachineRef) : OrcJITTargetMachineBuilderRef
  fun orc_dispose_jit_target_machine_builder = LLVMOrcDisposeJITTargetMachineBuilder(jtmb : OrcJITTargetMachineBuilderRef)
  fun orc_jit_target_machine_builder_get_target_triple = LLVMOrcJITTargetMachineBuilderGetTargetTriple(jtmb : OrcJITTargetMachineBuilderRef) : Char*
  fun orc_jit_target_machine_builder_set_target_triple = LLVMOrcJITTargetMachineBuilderSetTargetTriple(jtmb : OrcJITTargetMachineBuilderRef, target_triple : Char*)

  fun orc_object_layer_add_object_file = LLVMOrcObjectLayerAddObjectFile(obj_layer : OrcObjectLayerRef, jd : OrcJITDylibRef, obj_buffer : MemoryBufferRef) : ErrorRef
  fun orc_object_layer_add_object_file_with_rt = LLVMOrcObjectLayerAddObjectFileWithRT(obj_layer : OrcObjectLayerRef, rt : OrcResourceTrackerRef, obj_buffer : MemoryBufferRef) : ErrorRef
  fun orc_object_layer_emit = LLVMOrcObjectLayerEmit(obj_layer : OrcObjectLayerRef, r : OrcMaterializationResponsibilityRef, obj_buffer : MemoryBufferRef)
  fun orc_dispose_object_layer = LLVMOrcDisposeObjectLayer(obj_layer : OrcObjectLayerRef)
  fun orc_ir_transform_layer_emit = LLVMOrcIRTransformLayerEmit(ir_transform_layer : OrcIRTransformLayerRef, mr : OrcMaterializationResponsibilityRef, tsm : OrcThreadSafeModuleRef)
  fun orc_ir_transform_layer_set_transform = LLVMOrcIRTransformLayerSetTransform(ir_transform_layer : OrcIRTransformLayerRef, transform_function : OrcIRTransformLayerTransformFunction, ctx : Void*)
  fun orc_object_transform_layer_set_transform = LLVMOrcObjectTransformLayerSetTransform(obj_transform_layer : OrcObjectTransformLayerRef, transform_function : OrcObjectTransformLayerTransformFunction, ctx : Void*)

  fun orc_create_local_indirect_stubs_manager = LLVMOrcCreateLocalIndirectStubsManager(target_triple : Char*) : OrcIndirectStubsManagerRef
  fun orc_dispose_indirect_stubs_manager = LLVMOrcDisposeIndirectStubsManager(ism : OrcIndirectStubsManagerRef)
  fun orc_create_local_lazy_call_through_manager = LLVMOrcCreateLocalLazyCallThroughManager(target_triple : Char*, es : OrcExecutionSessionRef, error_handler_addr : OrcExecutorAddress, lctm : OrcLazyCallThroughManagerRef*) : ErrorRef
  fun orc_dispose_lazy_call_through_manager = LLVMOrcDisposeLazyCallThroughManager(lctm : OrcLazyCallThroughManagerRef)

  fun orc_create_dump_objects = LLVMOrcCreateDumpObjects(dump_dir : Char*, identifier_override : Char*) : OrcDumpObjectsRef
  fun orc_dispose_dump_objects = LLVMOrcDisposeDumpObjects(dump_objects : OrcDumpObjectsRef)
  fun orc_dump_objects_call_operator = LLVMOrcDumpObjects_CallOperator(dump_objects : OrcDumpObjectsRef, obj_buffer : MemoryBufferRef*) : ErrorRef
end
