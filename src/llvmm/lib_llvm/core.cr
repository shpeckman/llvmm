# src/llvmm/lib_llvm/core.cr
require "./types"

lib LibLLVMM
  enum ModuleFlagBehavior
    Error        = 0
    Warning      = 1
    Require      = 2
    Override     = 3
    Append       = 4
    AppendUnique = 5
  end

  alias AttributeIndex = UInt

  fun dispose_message = LLVMDisposeMessage(message : Char*)

  fun get_version = LLVMGetVersion(major : UInt*, minor : UInt*, patch : UInt*) : Void

  alias DiagnosticHandler = DiagnosticInfoRef, Void* -> Void

  fun create_context = LLVMContextCreate : ContextRef
  fun dispose_context = LLVMContextDispose(c : ContextRef)
  fun set_diagnostic_handler = LLVMContextSetDiagnosticHandler(c : ContextRef, handler : DiagnosticHandler, diagnostic_context : Void*)
  fun get_diag_info_description = LLVMGetDiagInfoDescription(di : DiagnosticInfoRef) : Char*
  fun get_diag_info_severity = LLVMGetDiagInfoSeverity(di : DiagnosticInfoRef) : LLVMM::DiagnosticSeverity
  fun set_discard_value_names = LLVMContextSetDiscardValueNames(c : ContextRef, discard : Bool)
  fun should_discard_value_names = LLVMContextShouldDiscardValueNames(c : ContextRef) : Bool

  fun get_md_kind_id_in_context = LLVMGetMDKindIDInContext(c : ContextRef, name : Char*, s_len : UInt) : UInt

  fun get_enum_attribute_kind_for_name = LLVMGetEnumAttributeKindForName(name : Char*, s_len : SizeT) : UInt
  fun get_last_enum_attribute_kind = LLVMGetLastEnumAttributeKind : UInt
  fun create_enum_attribute = LLVMCreateEnumAttribute(c : ContextRef, kind_id : UInt, val : UInt64) : AttributeRef
  fun create_string_attribute = LLVMCreateStringAttribute(c : ContextRef, k : Char*, k_length : UInt, v : Char*, v_length : UInt) : AttributeRef
  fun create_type_attribute = LLVMCreateTypeAttribute(c : ContextRef, kind_id : UInt, type_ref : TypeRef) : AttributeRef

  fun module_create_with_name_in_context = LLVMModuleCreateWithNameInContext(module_id : Char*, c : ContextRef) : ModuleRef
  fun clone_module = LLVMCloneModule(m : ModuleRef) : ModuleRef
  fun get_module_identifier = LLVMGetModuleIdentifier(m : ModuleRef, len : SizeT*) : Char*
  fun set_module_identifier = LLVMSetModuleIdentifier(m : ModuleRef, ident : Char*, len : SizeT)
  fun set_target = LLVMSetTarget(m : ModuleRef, triple : Char*)
  fun set_data_layout = LLVMSetDataLayout(m : ModuleRef, data_layout : Char*)
  fun get_data_layout_str = LLVMGetDataLayoutStr(m : ModuleRef) : Char*
  fun set_module_inline_asm2 = LLVMSetModuleInlineAsm2(m : ModuleRef, assembly : Char*, len : SizeT)
  fun get_module_inline_asm = LLVMGetModuleInlineAsm(m : ModuleRef, len : SizeT*) : Char*
  fun append_module_inline_asm = LLVMAppendModuleInlineAsm(m : ModuleRef, assembly : Char*, len : SizeT)
  fun add_module_flag = LLVMAddModuleFlag(m : ModuleRef, behavior : ModuleFlagBehavior, key : Char*, key_len : SizeT, val : MetadataRef)

  fun copy_module_flags_metadata = LLVMCopyModuleFlagsMetadata(m : ModuleRef, len : SizeT*) : ModuleFlagEntriesRef
  fun dispose_module_flags_metadata = LLVMDisposeModuleFlagsMetadata(entries : ModuleFlagEntriesRef)
  fun module_flag_entries_get_flag_behavior = LLVMModuleFlagEntriesGetFlagBehavior(entries : ModuleFlagEntriesRef, index : UInt) : ModuleFlagBehavior
  fun module_flag_entries_get_key = LLVMModuleFlagEntriesGetKey(entries : ModuleFlagEntriesRef, index : UInt, len : SizeT*) : Char*
  fun module_flag_entries_get_metadata = LLVMModuleFlagEntriesGetMetadata(entries : ModuleFlagEntriesRef, index : UInt) : MetadataRef
  fun get_module_flag = LLVMGetModuleFlag(m : ModuleRef, key : Char*, key_len : SizeT) : MetadataRef

  fun get_first_named_metadata = LLVMGetFirstNamedMetadata(m : ModuleRef) : NamedMDNodeRef
  fun get_last_named_metadata = LLVMGetLastNamedMetadata(m             : ModuleRef) : NamedMDNodeRef
  fun get_next_named_metadata = LLVMGetNextNamedMetadata(named_md_node : NamedMDNodeRef) : NamedMDNodeRef
  fun get_previous_named_metadata = LLVMGetPreviousNamedMetadata(named_md_node : NamedMDNodeRef) : NamedMDNodeRef
  fun get_named_metadata = LLVMGetNamedMetadata(m : ModuleRef, name : Char*, name_len : SizeT) : NamedMDNodeRef
  fun get_or_insert_named_metadata = LLVMGetOrInsertNamedMetadata(m : ModuleRef, name : Char*, name_len : SizeT) : NamedMDNodeRef
  fun get_named_metadata_name = LLVMGetNamedMetadataName(named_md : NamedMDNodeRef, name_len : SizeT*) : Char*
  fun get_named_metadata_num_operands = LLVMGetNamedMetadataNumOperands(m : ModuleRef, name : Char*) : UInt
  fun get_named_metadata_operands = LLVMGetNamedMetadataOperands(m : ModuleRef, name : Char*, dest : ValueRef*)
  fun add_named_metadata_operand = LLVMAddNamedMetadataOperand(m : ModuleRef, name : Char*, val : ValueRef)

  fun add_alias2 = LLVMAddAlias2(m : ModuleRef, value_ty : TypeRef, addr_space : UInt, aliasee : ValueRef, name : Char*) : ValueRef
  fun get_named_global_alias = LLVMGetNamedGlobalAlias(m : ModuleRef, name : Char*, name_len : SizeT) : ValueRef
  fun get_first_global_alias = LLVMGetFirstGlobalAlias(m : ModuleRef) : ValueRef
  fun get_last_global_alias = LLVMGetLastGlobalAlias(m  : ModuleRef) : ValueRef
  fun get_next_global_alias = LLVMGetNextGlobalAlias(ga : ValueRef) : ValueRef
  fun get_previous_global_alias = LLVMGetPreviousGlobalAlias(ga : ValueRef) : ValueRef
  fun alias_get_aliasee = LLVMAliasGetAliasee(ga : ValueRef) : ValueRef
  fun alias_set_aliasee = LLVMAliasSetAliasee(ga : ValueRef, aliasee : ValueRef)

  fun add_global_ifunc = LLVMAddGlobalIFunc(m : ModuleRef, name : Char*, name_len : SizeT, ty : TypeRef, addr_space : UInt, resolver : ValueRef) : ValueRef
  fun get_named_global_ifunc = LLVMGetNamedGlobalIFunc(m : ModuleRef, name : Char*, name_len : SizeT) : ValueRef
  fun get_first_global_ifunc = LLVMGetFirstGlobalIFunc(m : ModuleRef) : ValueRef
  fun get_last_global_ifunc = LLVMGetLastGlobalIFunc(m     : ModuleRef) : ValueRef
  fun get_next_global_ifunc = LLVMGetNextGlobalIFunc(ifunc : ValueRef) : ValueRef
  fun get_previous_global_ifunc = LLVMGetPreviousGlobalIFunc(ifunc : ValueRef) : ValueRef
  fun get_global_ifunc_resolver = LLVMGetGlobalIFuncResolver(ifunc : ValueRef) : ValueRef
  fun set_global_ifunc_resolver = LLVMSetGlobalIFuncResolver(ifunc : ValueRef, resolver : ValueRef)
  fun erase_global_ifunc = LLVMEraseGlobalIFunc(ifunc : ValueRef)
  fun remove_global_ifunc = LLVMRemoveGlobalIFunc(ifunc : ValueRef)
  fun dump_module = LLVMDumpModule(m : ModuleRef)
  fun print_module_to_file = LLVMPrintModuleToFile(m : ModuleRef, filename : Char*, error_message : Char**) : Bool
  fun print_module_to_string = LLVMPrintModuleToString(m : ModuleRef) : Char*
  fun get_inline_asm = LLVMGetInlineAsm(ty : TypeRef, asm_string : Char*, asm_string_size : SizeT, constraints : Char*, constraints_size : SizeT, has_side_effects : Bool, is_align_stack : Bool, dialect : LLVMM::InlineAsmDialect, can_throw : Bool) : ValueRef
  fun get_module_context = LLVMGetModuleContext(m : ModuleRef) : ContextRef

  fun add_function = LLVMAddFunction(m : ModuleRef, name : Char*, function_ty : TypeRef) : ValueRef
  {% unless LibLLVMM::IS_LT_220 %}
    fun get_or_insert_function = LLVMGetOrInsertFunction(m : ModuleRef, name : Char*, name_len : SizeT, function_ty : TypeRef) : ValueRef
  {% end %}
  {% if LibLLVMM::IS_LT_200 %}
    fun get_named_function = LLVMGetNamedFunction(m : ModuleRef, name : Char*) : ValueRef
  {% else %}
    fun get_named_function_with_length = LLVMGetNamedFunctionWithLength(m : ModuleRef, name : Char*, length : SizeT) : ValueRef
  {% end %}
  fun get_first_function = LLVMGetFirstFunction(m : ModuleRef) : ValueRef
  fun get_next_function = LLVMGetNextFunction(fn : ValueRef) : ValueRef

  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : LLVMM::Type::Kind
  fun get_type_context = LLVMGetTypeContext(ty : TypeRef) : ContextRef
  fun print_type_to_string = LLVMPrintTypeToString(ty : TypeRef) : Char*

  fun int1_type_in_context = LLVMInt1TypeInContext(c : ContextRef) : TypeRef
  fun int8_type_in_context = LLVMInt8TypeInContext(c : ContextRef) : TypeRef
  fun int16_type_in_context = LLVMInt16TypeInContext(c : ContextRef) : TypeRef
  fun int32_type_in_context = LLVMInt32TypeInContext(c : ContextRef) : TypeRef
  fun int64_type_in_context = LLVMInt64TypeInContext(c : ContextRef) : TypeRef
  fun int128_type_in_context = LLVMInt128TypeInContext(c : ContextRef) : TypeRef
  fun int_type_in_context = LLVMIntTypeInContext(c : ContextRef, num_bits : UInt) : TypeRef
  fun get_int_type_width = LLVMGetIntTypeWidth(integer_ty : TypeRef) : UInt

  fun half_type_in_context = LLVMHalfTypeInContext(c : ContextRef) : TypeRef
  fun bfloat_type = LLVMBFloatType : TypeRef
  fun bfloat_type_in_context = LLVMBFloatTypeInContext(c : ContextRef) : TypeRef
  fun float_type_in_context = LLVMFloatTypeInContext(c : ContextRef) : TypeRef
  fun double_type_in_context = LLVMDoubleTypeInContext(c : ContextRef) : TypeRef
  fun x86_fp80_type = LLVMX86FP80Type : TypeRef
  fun x86_fp80_type_in_context = LLVMX86FP80TypeInContext(c : ContextRef) : TypeRef
  fun fp128_type_in_context = LLVMFP128TypeInContext(c : ContextRef) : TypeRef
  fun ppc_fp128_type_in_context = LLVMPPCFP128TypeInContext(c : ContextRef) : TypeRef

  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt, is_var_arg : Bool) : TypeRef
  fun is_function_var_arg = LLVMIsFunctionVarArg(function_ty : TypeRef) : Bool
  fun get_return_type = LLVMGetReturnType(function_ty : TypeRef) : TypeRef
  fun count_param_types = LLVMCountParamTypes(function_ty : TypeRef) : UInt
  fun get_param_types = LLVMGetParamTypes(function_ty : TypeRef, dest : TypeRef*)

  fun struct_type = LLVMStructType(element_types : TypeRef*, element_count : UInt, packed : Bool) : TypeRef
  fun struct_type_in_context = LLVMStructTypeInContext(c : ContextRef, element_types : TypeRef*, element_count : UInt, packed : Bool) : TypeRef
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : Char*) : TypeRef
  fun get_struct_name = LLVMGetStructName(ty        : TypeRef) : Char*
  fun struct_set_body = LLVMStructSetBody(struct_ty : TypeRef, element_types : TypeRef*, element_count : UInt, packed : Bool)
  fun count_struct_element_types = LLVMCountStructElementTypes(struct_ty : TypeRef) : UInt
  fun get_struct_element_types = LLVMGetStructElementTypes(struct_ty : TypeRef, dest : TypeRef*)
  fun struct_get_type_at_index = LLVMStructGetTypeAtIndex(struct_ty : TypeRef, i : UInt) : TypeRef
  fun is_packed_struct = LLVMIsPackedStruct(struct_ty : TypeRef) : Bool

  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun array_type2 = LLVMArrayType2(element_type : TypeRef, element_count : ULongLong) : TypeRef
  fun get_array_length = LLVMGetArrayLength(array_ty : TypeRef) : UInt
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt) : TypeRef
  fun pointer_type_in_context = LLVMPointerTypeInContext(c : ContextRef, address_space : UInt) : TypeRef
  fun vector_type = LLVMVectorType(element_type : TypeRef, element_count : UInt) : TypeRef
  fun scalable_vector_type = LLVMScalableVectorType(element_type : TypeRef, element_count : UInt) : TypeRef
  fun get_vector_size = LLVMGetVectorSize(vector_ty : TypeRef) : UInt

  fun void_type = LLVMVoidType : TypeRef
  fun void_type_in_context = LLVMVoidTypeInContext(c : ContextRef) : TypeRef
  fun x86_amx_type = LLVMX86AMXType : TypeRef
  fun x86_amx_type_in_context = LLVMX86AMXTypeInContext(c : ContextRef) : TypeRef
  fun token_type_in_context = LLVMTokenTypeInContext(c : ContextRef) : TypeRef

  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun global_get_value_type = LLVMGlobalGetValueType(global : ValueRef) : TypeRef
  fun get_value_kind = LLVMGetValueKind(val : ValueRef) : LLVMM::Value::Kind
  fun get_value_name2 = LLVMGetValueName2(val : ValueRef, length : SizeT*) : Char*
  fun set_value_name2 = LLVMSetValueName2(val : ValueRef, name : Char*, name_len : SizeT)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun print_value_to_string = LLVMPrintValueToString(val : ValueRef) : Char*
  fun is_constant = LLVMIsConstant(val : ValueRef) : Bool
  fun get_value_name = LLVMGetValueName(val : ValueRef) : Char*
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : Char*)

  fun get_operand = LLVMGetOperand(val : ValueRef, index : UInt) : ValueRef
  fun set_operand = LLVMSetOperand(user : ValueRef, index : UInt, val : ValueRef)
  fun get_operand_use = LLVMGetOperandUse(val : ValueRef, index : UInt) : UseRef
  fun get_num_operands = LLVMGetNumOperands(val : ValueRef) : Int

  fun const_null = LLVMConstNull(ty : TypeRef) : ValueRef
  fun get_undef = LLVMGetUndef(ty : TypeRef) : ValueRef
  fun const_pointer_null = LLVMConstPointerNull(ty : TypeRef) : ValueRef

  fun const_int = LLVMConstInt(int_ty : TypeRef, n : ULongLong, sign_extend : Bool) : ValueRef
  fun const_int_of_arbitrary_precision = LLVMConstIntOfArbitraryPrecision(int_ty : TypeRef, num_words : UInt, words : UInt64*) : ValueRef
  fun const_real = LLVMConstReal(real_ty : TypeRef, n : Double) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_ty : TypeRef, text : Char*) : ValueRef
  fun const_real_of_string_and_size = LLVMConstRealOfStringAndSize(real_ty : TypeRef, text : Char*, s_len : UInt) : ValueRef
  fun const_int_get_zext_value = LLVMConstIntGetZExtValue(constant_val : ValueRef) : ULongLong
  fun const_int_get_sext_value = LLVMConstIntGetSExtValue(constant_val : ValueRef) : LongLong

  {% if LibLLVMM::IS_LT_190 %}
    fun const_string_in_context = LLVMConstStringInContext(c : ContextRef, str : Char*, length : UInt, dont_null_terminate : Bool) : ValueRef
  {% else %}
    fun const_string_in_context2 = LLVMConstStringInContext2(c : ContextRef, str : Char*, length : SizeT, dont_null_terminate : Bool) : ValueRef
  {% end %}
  fun const_struct_in_context = LLVMConstStructInContext(c : ContextRef, constant_vals : ValueRef*, count : UInt, packed : Bool) : ValueRef
  fun const_array = LLVMConstArray(element_ty : TypeRef, constant_vals : ValueRef*, length : UInt) : ValueRef
  fun const_vector = LLVMConstVector(scalar_constants : ValueRef*, size : UInt) : ValueRef
  fun const_named_struct = LLVMConstNamedStruct(struct_ty : TypeRef, constant_vals : ValueRef*, count : UInt) : ValueRef
  fun const_int_of_string = LLVMConstIntOfString(int_ty : TypeRef, text : Char*, radix : UInt8) : ValueRef
  fun const_int_of_string_and_size = LLVMConstIntOfStringAndSize(int_ty : TypeRef, text : Char*, s_len : UInt, radix : UInt8) : ValueRef
  fun const_real_get_double = LLVMConstRealGetDouble(constant_val : ValueRef, loses_info : Bool*) : Double
  fun const_gep2 = LLVMConstGEP2(ty : TypeRef, constant_val : ValueRef, constant_indices : ValueRef*, num_indices : UInt) : ValueRef
  fun const_in_bounds_gep2 = LLVMConstInBoundsGEP2(ty : TypeRef, constant_val : ValueRef, constant_indices : ValueRef*, num_indices : UInt) : ValueRef
  fun const_extract_element = LLVMConstExtractElement(vector_constant : ValueRef, index_constant : ValueRef) : ValueRef
  fun const_insert_element = LLVMConstInsertElement(vector_constant : ValueRef, element_value_constant : ValueRef, index_constant : ValueRef) : ValueRef
  fun const_shuffle_vector = LLVMConstShuffleVector(vector_a_constant : ValueRef, vector_b_constant : ValueRef, mask_constant : ValueRef) : ValueRef
  {% unless LibLLVMM::IS_LT_210 %}
    fun const_data_array = LLVMConstDataArray(element_ty : TypeRef, data : Char*, size_in_bytes : SizeT) : ValueRef
  {% end %}

  fun align_of = LLVMAlignOf(ty : TypeRef) : ValueRef
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef

  fun get_global_parent = LLVMGetGlobalParent(global : ValueRef) : ModuleRef
  fun get_linkage = LLVMGetLinkage(global : ValueRef) : LLVMM::Linkage
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : LLVMM::Linkage)
  fun set_dll_storage_class = LLVMSetDLLStorageClass(global : ValueRef, class : LLVMM::DLLStorageClass)

  fun set_alignment = LLVMSetAlignment(v : ValueRef, bytes : UInt)
  fun get_alignment = LLVMGetAlignment(v : ValueRef) : UInt

  fun add_global = LLVMAddGlobal(m : ModuleRef, ty : TypeRef, name : Char*) : ValueRef
  {% if LibLLVMM::IS_LT_200 %}
    fun get_named_global = LLVMGetNamedGlobal(m : ModuleRef, name : Char*) : ValueRef
  {% else %}
    fun get_named_global_with_length = LLVMGetNamedGlobalWithLength(m : ModuleRef, name : Char*, length : SizeT) : ValueRef
  {% end %}
  fun get_initializer = LLVMGetInitializer(global_var : ValueRef) : ValueRef
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun is_thread_local = LLVMIsThreadLocal(global_var : ValueRef) : Bool
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Bool)
  fun is_global_constant = LLVMIsGlobalConstant(global_var : ValueRef) : Bool
  fun set_global_constant = LLVMSetGlobalConstant(global_var : ValueRef, is_constant : Bool)
  fun global_set_metadata = LLVMGlobalSetMetadata(global_var : ValueRef, kind : UInt, md : MetadataRef)

  fun add_global_in_address_space = LLVMAddGlobalInAddressSpace(m : ModuleRef, ty : TypeRef, name : Char*, address_space : UInt) : ValueRef
  fun delete_global = LLVMDeleteGlobal(global_var : ValueRef)
  fun get_first_global = LLVMGetFirstGlobal(m : ModuleRef) : ValueRef
  fun get_last_global = LLVMGetLastGlobal(m          : ModuleRef) : ValueRef
  fun get_next_global = LLVMGetNextGlobal(global_var : ValueRef) : ValueRef
  fun get_previous_global = LLVMGetPreviousGlobal(global_var : ValueRef) : ValueRef
  fun get_section = LLVMGetSection(global : ValueRef) : Char*
  fun set_section = LLVMSetSection(global : ValueRef, section : Char*)
  fun get_visibility = LLVMGetVisibility(global : ValueRef) : LLVMM::Visibility
  fun set_visibility = LLVMSetVisibility(global : ValueRef, viz : LLVMM::Visibility)
  fun get_dll_storage_class = LLVMGetDLLStorageClass(global : ValueRef) : LLVMM::DLLStorageClass
  fun get_unnamed_address = LLVMGetUnnamedAddress(global : ValueRef) : LLVMM::UnnamedAddress
  fun set_unnamed_address = LLVMSetUnnamedAddress(global : ValueRef, unnamed_addr : LLVMM::UnnamedAddress)
  fun get_thread_local_mode = LLVMGetThreadLocalMode(global_var : ValueRef) : LLVMM::ThreadLocalMode
  fun set_thread_local_mode = LLVMSetThreadLocalMode(global_var : ValueRef, mode : LLVMM::ThreadLocalMode)
  fun is_externally_initialized = LLVMIsExternallyInitialized(global_var : ValueRef) : Bool
  fun set_externally_initialized = LLVMSetExternallyInitialized(global_var : ValueRef, is_ext_init : Bool)
  fun set_inst_debug_location = LLVMSetInstDebugLocation(builder : BuilderRef, inst : ValueRef)
  fun global_clear_metadata = LLVMGlobalClearMetadata(global : ValueRef)
  fun global_copy_all_metadata = LLVMGlobalCopyAllMetadata(value : ValueRef, num_entries : SizeT*) : ValueMetadataEntryRef
  fun global_erase_metadata = LLVMGlobalEraseMetadata(global : ValueRef, kind : UInt)

  fun delete_function = LLVMDeleteFunction(fn : ValueRef)
  fun has_personality_fn = LLVMHasPersonalityFn(fn : ValueRef) : Bool
  fun get_personality_fn = LLVMGetPersonalityFn(fn : ValueRef) : ValueRef
  fun set_personality_fn = LLVMSetPersonalityFn(fn : ValueRef, personality_fn : ValueRef)
  fun get_function_call_convention = LLVMGetFunctionCallConv(fn : ValueRef) : LLVMM::CallConvention
  fun set_function_call_convention = LLVMSetFunctionCallConv(fn : ValueRef, cc : LLVMM::CallConvention)
  fun add_attribute_at_index = LLVMAddAttributeAtIndex(f : ValueRef, idx : AttributeIndex, a : AttributeRef)
  fun get_enum_attribute_at_index = LLVMGetEnumAttributeAtIndex(f : ValueRef, idx : AttributeIndex, kind_id : UInt) : AttributeRef
  fun add_target_dependent_function_attr = LLVMAddTargetDependentFunctionAttr(fn : ValueRef, a : Char*, v : Char*)

  fun get_count_params = LLVMCountParams(fn : ValueRef) : UInt
  fun get_params = LLVMGetParams(fn : ValueRef, params : ValueRef*)
  fun get_param = LLVMGetParam(fn : ValueRef, index : UInt) : ValueRef
  fun set_param_alignment = LLVMSetParamAlignment(arg : ValueRef, align : UInt)

  fun md_string_in_context2 = LLVMMDStringInContext2(c : ContextRef, str : Char*, s_len : SizeT) : ValueRef
  fun md_node_in_context2 = LLVMMDNodeInContext2(c : ContextRef, mds : MetadataRef*, count : SizeT) : MetadataRef
  fun metadata_as_value = LLVMMetadataAsValue(c : ContextRef, md : MetadataRef) : ValueRef
  fun value_as_metadata = LLVMValueAsMetadata(val : ValueRef) : MetadataRef
  fun get_md_node_num_operands = LLVMGetMDNodeNumOperands(v : ValueRef) : UInt
  fun get_md_node_operands = LLVMGetMDNodeOperands(v : ValueRef, dest : ValueRef*)
  fun replace_md_node_operand_with = LLVMReplaceMDNodeOperandWith(v : ValueRef, index : UInt, replacement : MetadataRef)

  fun has_metadata = LLVMHasMetadata(val : ValueRef) : LibC::Int
  fun get_metadata = LLVMGetMetadata(val : ValueRef, kind_id : UInt) : ValueRef
  fun instruction_get_all_metadata_other_than_debug_loc = LLVMInstructionGetAllMetadataOtherThanDebugLoc(instr : ValueRef, num_entries : SizeT*) : ValueMetadataEntryRef
  fun dispose_value_metadata_entries = LLVMDisposeValueMetadataEntries(entries : ValueMetadataEntryRef)
  fun value_metadata_entries_get_kind = LLVMValueMetadataEntriesGetKind(entries : ValueMetadataEntryRef, index : UInt) : UInt
  fun value_metadata_entries_get_metadata = LLVMValueMetadataEntriesGetMetadata(entries : ValueMetadataEntryRef, index : UInt) : MetadataRef
  fun is_a_value_as_metadata = LLVMIsAValueAsMetadata(val : ValueRef) : ValueRef
  fun metadata_type_in_context = LLVMMetadataTypeInContext(c : ContextRef) : TypeRef

  fun create_operand_bundle = LLVMCreateOperandBundle(tag : Char*, tag_len : SizeT, args : ValueRef*, num_args : UInt) : OperandBundleRef
  fun dispose_operand_bundle = LLVMDisposeOperandBundle(bundle : OperandBundleRef)
  fun get_num_operand_bundles = LLVMGetNumOperandBundles(c : ValueRef) : UInt
  fun get_operand_bundle_at_index = LLVMGetOperandBundleAtIndex(c : ValueRef, index : UInt) : OperandBundleRef
  fun get_num_operand_bundle_args = LLVMGetNumOperandBundleArgs(bundle : OperandBundleRef) : UInt
  fun get_operand_bundle_arg_at_index = LLVMGetOperandBundleArgAtIndex(bundle : OperandBundleRef, index : UInt) : ValueRef
  fun get_operand_bundle_tag = LLVMGetOperandBundleTag(bundle : OperandBundleRef, len : SizeT*) : Char*

  fun get_basic_block_name = LLVMGetBasicBlockName(bb : BasicBlockRef) : Char*
  fun get_basic_block_parent = LLVMGetBasicBlockParent(bb : BasicBlockRef) : ValueRef
  fun get_first_basic_block = LLVMGetFirstBasicBlock(fn : ValueRef) : BasicBlockRef
  fun get_next_basic_block = LLVMGetNextBasicBlock(bb : BasicBlockRef) : BasicBlockRef
  fun count_basic_blocks = LLVMCountBasicBlocks(fn : ValueRef) : UInt
  fun get_basic_blocks = LLVMGetBasicBlocks(fn : ValueRef, basic_blocks : BasicBlockRef*)
  fun block_address = LLVMBlockAddress(f : ValueRef, bb : BasicBlockRef) : ValueRef
  fun append_basic_block_in_context = LLVMAppendBasicBlockInContext(c : ContextRef, fn : ValueRef, name : Char*) : BasicBlockRef
  fun append_existing_basic_block = LLVMAppendExistingBasicBlock(fn : ValueRef, bb : BasicBlockRef)
  fun insert_basic_block = LLVMInsertBasicBlock(insert_before_bb : BasicBlockRef, name : Char*) : BasicBlockRef
  fun insert_basic_block_in_context = LLVMInsertBasicBlockInContext(c : ContextRef, bb : BasicBlockRef, name : Char*) : BasicBlockRef
  fun move_basic_block_before = LLVMMoveBasicBlockBefore(bb : BasicBlockRef, move_pos : BasicBlockRef)
  fun move_basic_block_after = LLVMMoveBasicBlockAfter(bb : BasicBlockRef, move_pos : BasicBlockRef)
  fun remove_basic_block_from_parent = LLVMRemoveBasicBlockFromParent(bb : BasicBlockRef)
  fun basic_block_as_value = LLVMBasicBlockAsValue(bb  : BasicBlockRef) : ValueRef
  fun value_as_basic_block = LLVMValueAsBasicBlock(val : ValueRef) : BasicBlockRef
  fun value_is_basic_block = LLVMValueIsBasicBlock(val : ValueRef) : Bool
  fun delete_basic_block = LLVMDeleteBasicBlock(bb : BasicBlockRef)
  fun get_first_instruction = LLVMGetFirstInstruction(bb : BasicBlockRef) : ValueRef

  fun set_metadata = LLVMSetMetadata(val : ValueRef, kind_id : UInt, node : ValueRef)
  fun get_next_instruction = LLVMGetNextInstruction(inst : ValueRef) : ValueRef

  fun get_num_arg_operands = LLVMGetNumArgOperands(instr : ValueRef) : UInt
  fun set_instruction_call_convention = LLVMSetInstructionCallConv(instr : ValueRef, cc : LLVMM::CallConvention)
  fun get_instruction_call_convention = LLVMGetInstructionCallConv(instr : ValueRef) : LLVMM::CallConvention
  fun set_instr_param_alignment = LLVMSetInstrParamAlignment(instr : ValueRef, idx : AttributeIndex, align : UInt)
  fun add_call_site_attribute = LLVMAddCallSiteAttribute(c : ValueRef, idx : AttributeIndex, a : AttributeRef)
  fun get_call_site_attribute_count = LLVMGetCallSiteAttributeCount(c : ValueRef, idx : AttributeIndex) : UInt
  fun get_call_site_attributes = LLVMGetCallSiteAttributes(c : ValueRef, idx : AttributeIndex, attrs : AttributeRef*)
  fun get_call_site_enum_attribute = LLVMGetCallSiteEnumAttribute(c : ValueRef, idx : AttributeIndex, kind_id : UInt) : AttributeRef
  fun get_call_site_string_attribute = LLVMGetCallSiteStringAttribute(c : ValueRef, idx : AttributeIndex, k : Char*, k_len : UInt) : AttributeRef
  fun remove_call_site_enum_attribute = LLVMRemoveCallSiteEnumAttribute(c : ValueRef, idx : AttributeIndex, kind_id : UInt)
  fun remove_call_site_string_attribute = LLVMRemoveCallSiteStringAttribute(c : ValueRef, idx : AttributeIndex, k : Char*, k_len : UInt)
  fun get_called_value = LLVMGetCalledValue(instr : ValueRef) : ValueRef
  fun get_called_function_type = LLVMGetCalledFunctionType(c : ValueRef) : TypeRef
  fun is_tail_call = LLVMIsTailCall(call_inst : ValueRef) : Bool
  fun set_tail_call = LLVMSetTailCall(call_inst : ValueRef, is_tail_call : Bool)
  fun get_tail_call_kind = LLVMGetTailCallKind(call_inst : ValueRef) : LLVMM::TailCallKind
  fun set_tail_call_kind = LLVMSetTailCallKind(call_inst : ValueRef, kind : LLVMM::TailCallKind)

  fun get_condition = LLVMGetCondition(branch : ValueRef) : ValueRef
  fun set_condition = LLVMSetCondition(branch : ValueRef, cond : ValueRef)
  fun is_conditional = LLVMIsConditional(branch : ValueRef) : Bool
  fun get_num_successors = LLVMGetNumSuccessors(term : ValueRef) : UInt
  fun get_successor = LLVMGetSuccessor(term : ValueRef, i : UInt) : BasicBlockRef
  fun set_successor = LLVMSetSuccessor(term : ValueRef, i : UInt, block : BasicBlockRef)

  fun get_nsw = LLVMGetNSW(arith_inst : ValueRef) : Bool
  fun set_nsw = LLVMSetNSW(arith_inst : ValueRef, has_nsw : Bool)
  fun get_nuw = LLVMGetNUW(arith_inst : ValueRef) : Bool
  fun set_nuw = LLVMSetNUW(arith_inst : ValueRef, has_nuw : Bool)
  fun get_exact = LLVMGetExact(div_or_shr_inst : ValueRef) : Bool
  fun set_exact = LLVMSetExact(div_or_shr_inst : ValueRef, is_exact : Bool)
  fun is_in_bounds = LLVMIsInBounds(gep : ValueRef) : Bool
  fun set_is_in_bounds = LLVMSetIsInBounds(gep : ValueRef, in_bounds : Bool)

  fun can_use_fast_math_flags = LLVMCanValueUseFastMathFlags(inst : ValueRef) : Bool
  fun get_fast_math_flags = LLVMGetFastMathFlags(fp_math_inst : ValueRef) : UInt
  fun set_fast_math_flags = LLVMSetFastMathFlags(fp_math_inst : ValueRef, fmf : UInt)

  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef*, count : UInt)

  fun create_builder_in_context = LLVMCreateBuilderInContext(c : ContextRef) : BuilderRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun dispose_builder = LLVMDisposeBuilder(builder : BuilderRef)

  fun get_current_debug_location2 = LLVMGetCurrentDebugLocation2(builder : BuilderRef) : MetadataRef
  fun set_current_debug_location2 = LLVMSetCurrentDebugLocation2(builder : BuilderRef, loc : MetadataRef)
  fun get_current_debug_location = LLVMGetCurrentDebugLocation(builder : BuilderRef) : ValueRef
  fun builder_get_default_fp_math_tag = LLVMBuilderGetDefaultFPMathTag(builder : BuilderRef) : MetadataRef
  fun builder_set_default_fp_math_tag = LLVMBuilderSetDefaultFPMathTag(builder : BuilderRef, fp_math_tag : MetadataRef)

  fun build_ret_void = LLVMBuildRetVoid(BuilderRef) : ValueRef
  fun build_ret = LLVMBuildRet(BuilderRef, v : ValueRef) : ValueRef
  fun build_aggregate_ret = LLVMBuildAggregateRet(BuilderRef, ret_vals : ValueRef*, n : UInt) : ValueRef
  fun build_br = LLVMBuildBr(BuilderRef, dest : BasicBlockRef) : ValueRef
  fun build_cond = LLVMBuildCondBr(BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef) : ValueRef
  fun build_switch = LLVMBuildSwitch(BuilderRef, v : ValueRef, else : BasicBlockRef, num_cases : UInt) : ValueRef
  fun build_indirect_br = LLVMBuildIndirectBr(b : BuilderRef, addr : ValueRef, num_dests : UInt) : ValueRef
  fun add_destination = LLVMAddDestination(indirect_br : ValueRef, dest : BasicBlockRef)
  fun build_invoke2 = LLVMBuildInvoke2(BuilderRef, ty : TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, then : BasicBlockRef, catch : BasicBlockRef, name : Char*) : ValueRef
  fun build_invoke_with_operand_bundles = LLVMBuildInvokeWithOperandBundles(BuilderRef, ty : TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, then : BasicBlockRef, catch : BasicBlockRef, bundles : OperandBundleRef*, num_bundles : UInt, name : Char*) : ValueRef
  fun build_unreachable = LLVMBuildUnreachable(BuilderRef) : ValueRef

  fun build_resume = LLVMBuildResume(b : BuilderRef, exn : ValueRef) : ValueRef
  fun build_landing_pad = LLVMBuildLandingPad(b : BuilderRef, ty : TypeRef, pers_fn : ValueRef, num_clauses : UInt, name : Char*) : ValueRef
  fun build_cleanup_ret = LLVMBuildCleanupRet(b : BuilderRef, catch_pad : ValueRef, bb : BasicBlockRef) : ValueRef
  fun build_catch_ret = LLVMBuildCatchRet(b : BuilderRef, catch_pad : ValueRef, bb : BasicBlockRef) : ValueRef
  fun build_catch_pad = LLVMBuildCatchPad(b : BuilderRef, parent_pad : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  fun build_cleanup_pad = LLVMBuildCleanupPad(b : BuilderRef, parent_pad : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  fun build_catch_switch = LLVMBuildCatchSwitch(b : BuilderRef, parent_pad : ValueRef, unwind_bb : BasicBlockRef, num_handlers : UInt, name : Char*) : ValueRef

  fun add_case = LLVMAddCase(switch : ValueRef, on_val : ValueRef, dest : BasicBlockRef)
  fun add_clause = LLVMAddClause(landing_pad : ValueRef, clause_val : ValueRef)
  fun set_cleanup = LLVMSetCleanup(landing_pad : ValueRef, val : Bool)
  fun add_handler = LLVMAddHandler(catch_switch : ValueRef, dest : BasicBlockRef)
  fun get_num_handlers = LLVMGetNumHandlers(catch_switch : ValueRef) : UInt
  fun get_handlers = LLVMGetHandlers(catch_switch : ValueRef, handlers : BasicBlockRef*)
  fun get_parent_catch_switch = LLVMGetParentCatchSwitch(catch_pad : ValueRef) : ValueRef
  fun set_parent_catch_switch = LLVMSetParentCatchSwitch(catch_pad : ValueRef, catch_switch : ValueRef)

  fun get_arg_operand = LLVMGetArgOperand(funclet : ValueRef, i : UInt) : ValueRef
  fun set_arg_operand = LLVMSetArgOperand(funclet : ValueRef, i : UInt, value : ValueRef)

  fun build_binop = LLVMBuildBinOp(b : BuilderRef, op : LLVMM::Opcode, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_add = LLVMBuildAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nsw_add = LLVMBuildNSWAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nuw_add = LLVMBuildNUWAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sub = LLVMBuildSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nsw_sub = LLVMBuildNSWSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nuw_sub = LLVMBuildNUWSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fsub = LLVMBuildFSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_mul = LLVMBuildMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nsw_mul = LLVMBuildNSWMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_nuw_mul = LLVMBuildNUWMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fmul = LLVMBuildFMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_udiv = LLVMBuildUDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_exact_udiv = LLVMBuildExactUDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_exact_sdiv = LLVMBuildExactSDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_urem = LLVMBuildURem(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_srem = LLVMBuildSRem(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_frem = LLVMBuildFRem(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_shl = LLVMBuildShl(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_lshr = LLVMBuildLShr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_ashr = LLVMBuildAShr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_and = LLVMBuildAnd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_or = LLVMBuildOr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_xor = LLVMBuildXor(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_not = LLVMBuildNot(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_neg = LLVMBuildNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_nsw_neg = LLVMBuildNSWNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_nuw_neg = LLVMBuildNUWNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_fneg = LLVMBuildFNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef

  fun build_malloc = LLVMBuildMalloc(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_free = LLVMBuildFree(BuilderRef, pointer_val : ValueRef) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(BuilderRef, ty : TypeRef, val : ValueRef, name : Char*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_load2 = LLVMBuildLoad2(BuilderRef, ty : TypeRef, pointer_val : ValueRef, name : Char*) : ValueRef
  fun build_store = LLVMBuildStore(BuilderRef, val : ValueRef, ptr : ValueRef) : ValueRef
  fun build_gep2 = LLVMBuildGEP2(b : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt, name : Char*) : ValueRef
  fun build_inbounds_gep2 = LLVMBuildInBoundsGEP2(b : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt, name : Char*) : ValueRef
  fun build_struct_gep2 = LLVMBuildStructGEP2(b : BuilderRef, ty : TypeRef, pointer : ValueRef, idx : UInt, name : Char*) : ValueRef
  fun build_global_string = LLVMBuildGlobalString(b : BuilderRef, str : Char*, name : Char*) : ValueRef
  fun build_global_string_ptr = LLVMBuildGlobalStringPtr(b : BuilderRef, str : Char*, name : Char*) : ValueRef
  fun set_volatile = LLVMSetVolatile(memory_access_inst : ValueRef, is_volatile : Bool)
  fun get_volatile = LLVMGetVolatile(memory_access_inst : ValueRef) : Bool
  fun set_ordering = LLVMSetOrdering(memory_access_inst : ValueRef, ordering : LLVMM::AtomicOrdering)
  fun get_ordering = LLVMGetOrdering(memory_access_inst : ValueRef) : LLVMM::AtomicOrdering

  fun build_trunc = LLVMBuildTrunc(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_zext = LLVMBuildZExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_sext = LLVMBuildSExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildUIToFP(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fpext = LLVMBuildFPExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ptr2int = LLVMBuildPtrToInt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_cast = LLVMBuildCast(b : BuilderRef, op : LLVMM::Opcode, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_int_cast2 = LLVMBuildIntCast2(BuilderRef, val : ValueRef, dest_ty : TypeRef, is_signed : Bool, name : Char*) : ValueRef
  fun build_fp_cast = LLVMBuildFPCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_pointer_cast = LLVMBuildPointerCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_addr_space_cast = LLVMBuildAddrSpaceCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_sext_or_bit_cast = LLVMBuildSExtOrBitCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_zext_or_bit_cast = LLVMBuildZExtOrBitCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_trunc_or_bit_cast = LLVMBuildTruncOrBitCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef

  fun build_icmp = LLVMBuildICmp(BuilderRef, op : LLVMM::IntPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(BuilderRef, op : LLVMM::RealPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun get_icmp_predicate = LLVMGetICmpPredicate(inst : ValueRef) : LLVMM::IntPredicate
  fun get_fcmp_predicate = LLVMGetFCmpPredicate(inst : ValueRef) : LLVMM::RealPredicate
  fun get_cast_opcode = LLVMGetCastOpcode(src : ValueRef, src_is_signed : Bool, dest_ty : TypeRef, dest_is_signed : Bool) : LLVMM::Opcode

  fun build_phi = LLVMBuildPhi(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun get_first_instruction = LLVMGetFirstInstruction(block : BasicBlockRef) : ValueRef
  fun position_builder = LLVMPositionBuilder(b : BuilderRef, block : BasicBlockRef, instr : ValueRef)
  fun insert_into_builder = LLVMInsertIntoBuilder(builder : BuilderRef, instr : ValueRef)
  fun insert_into_builder_with_name = LLVMInsertIntoBuilderWithName(builder : BuilderRef, instr : ValueRef, name : Char*)

  fun build_freeze = LLVMBuildFreeze(BuilderRef, val : ValueRef, name : Char*) : ValueRef
  fun build_is_null = LLVMBuildIsNull(BuilderRef, val : ValueRef, name : Char*) : ValueRef
  fun build_is_not_null = LLVMBuildIsNotNull(BuilderRef, val : ValueRef, name : Char*) : ValueRef
  fun build_ptr_diff2 = LLVMBuildPtrDiff2(BuilderRef, elem_ty : TypeRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef

  fun build_mem_set = LLVMBuildMemSet(b : BuilderRef, ptr : ValueRef, val : ValueRef, len : ValueRef, align : UInt) : ValueRef
  fun build_mem_cpy = LLVMBuildMemCpy(b : BuilderRef, dst : ValueRef, dst_align : UInt, src : ValueRef, src_align : UInt, size : ValueRef) : ValueRef
  fun build_mem_move = LLVMBuildMemMove(b : BuilderRef, dst : ValueRef, dst_align : UInt, src : ValueRef, src_align : UInt, size : ValueRef) : ValueRef
  fun build_array_alloca = LLVMBuildArrayAlloca(b : BuilderRef, ty : TypeRef, val : ValueRef, name : Char*) : ValueRef
  fun build_insert_value = LLVMBuildInsertValue(b : BuilderRef, agg_val : ValueRef, elt_val : ValueRef, index : UInt, name : Char*) : ValueRef
  fun build_extract_element = LLVMBuildExtractElement(b : BuilderRef, vec_val : ValueRef, index : ValueRef, name : Char*) : ValueRef
  fun build_insert_element = LLVMBuildInsertElement(b : BuilderRef, vec_val : ValueRef, elt_val : ValueRef, index : ValueRef, name : Char*) : ValueRef
  fun build_shuffle_vector = LLVMBuildShuffleVector(b : BuilderRef, v1 : ValueRef, v2 : ValueRef, mask : ValueRef, name : Char*) : ValueRef
  fun build_call2 = LLVMBuildCall2(BuilderRef, TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  fun build_call_with_operand_bundles = LLVMBuildCallWithOperandBundles(BuilderRef, TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, bundles : OperandBundleRef*, num_bundles : UInt, name : Char*) : ValueRef
  fun build_select = LLVMBuildSelect(BuilderRef, if : ValueRef, then : ValueRef, else : ValueRef, name : Char*) : ValueRef
  fun build_va_arg = LLVMBuildVAArg(BuilderRef, list : ValueRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(BuilderRef, agg_val : ValueRef, index : UInt, name : Char*) : ValueRef
  fun build_fence = LLVMBuildFence(b : BuilderRef, ordering : LLVMM::AtomicOrdering, single_thread : Bool, name : Char*) : ValueRef
  fun build_atomicrmw = LLVMBuildAtomicRMW(b : BuilderRef, op : LLVMM::AtomicRMWBinOp, ptr : ValueRef, val : ValueRef, ordering : LLVMM::AtomicOrdering, single_thread : Bool) : ValueRef
  fun build_atomic_cmp_xchg = LLVMBuildAtomicCmpXchg(b : BuilderRef, ptr : ValueRef, cmp : ValueRef, new : ValueRef, success_ordering : LLVMM::AtomicOrdering, failure_ordering : LLVMM::AtomicOrdering, single_thread : Bool) : ValueRef
  fun get_atomicrmw_bin_op = LLVMGetAtomicRMWBinOp(atomicrmw_inst : ValueRef) : LLVMM::AtomicRMWBinOp
  fun set_atomicrmw_bin_op = LLVMSetAtomicRMWBinOp(atomicrmw_inst : ValueRef, bin_op : LLVMM::AtomicRMWBinOp)
  fun get_cmpxchg_success_ordering = LLVMGetCmpXchgSuccessOrdering(cmpxchg_inst : ValueRef) : LLVMM::AtomicOrdering
  fun set_cmpxchg_success_ordering = LLVMSetCmpXchgSuccessOrdering(cmpxchg_inst : ValueRef, ordering : LLVMM::AtomicOrdering)
  fun get_cmpxchg_failure_ordering = LLVMGetCmpXchgFailureOrdering(cmpxchg_inst : ValueRef) : LLVMM::AtomicOrdering
  fun set_cmpxchg_failure_ordering = LLVMSetCmpXchgFailureOrdering(cmpxchg_inst : ValueRef, ordering : LLVMM::AtomicOrdering)
  fun is_atomic_single_thread = LLVMIsAtomicSingleThread(atomic_inst : ValueRef) : Bool
  fun set_atomic_single_thread = LLVMSetAtomicSingleThread(atomic_inst : ValueRef, single_thread : Bool)

  fun create_memory_buffer_with_contents_of_file = LLVMCreateMemoryBufferWithContentsOfFile(path : Char*, out_mem_buf : MemoryBufferRef*, out_message : Char**) : Bool
  fun get_buffer_start = LLVMGetBufferStart(mem_buf : MemoryBufferRef) : Char*
  fun get_buffer_size = LLVMGetBufferSize(mem_buf : MemoryBufferRef) : SizeT
  fun dispose_memory_buffer = LLVMDisposeMemoryBuffer(mem_buf : MemoryBufferRef)

  fun target_ext_type_in_context = LLVMTargetExtTypeInContext(c : ContextRef, name : Char*, type_params : TypeRef*, type_param_count : UInt, int_params : UInt*, int_param_count : UInt) : TypeRef
  {% unless LibLLVMM::IS_LT_190 %}
    fun get_target_ext_type_name = LLVMGetTargetExtTypeName(target_ext_ty : TypeRef) : Char*
    fun get_target_ext_type_int_param = LLVMGetTargetExtTypeIntParam(target_ext_ty : TypeRef, idx : UInt) : UInt
    fun get_target_ext_type_type_param = LLVMGetTargetExtTypeTypeParam(target_ext_ty : TypeRef, idx : UInt) : TypeRef
    fun get_target_ext_type_num_int_params = LLVMGetTargetExtTypeNumIntParams(target_ext_ty : TypeRef) : UInt
    fun get_target_ext_type_num_type_params = LLVMGetTargetExtTypeNumTypeParams(target_ext_ty : TypeRef) : UInt

    fun build_gep_with_no_wrap_flags = LLVMBuildGEPWithNoWrapFlags(b : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt, name : Char*, no_wrap_flags : LLVMM::GEPNoWrapFlags) : ValueRef
    fun const_gep_with_no_wrap_flags = LLVMConstGEPWithNoWrapFlags(ty : TypeRef, constant_val : ValueRef, constant_indices : ValueRef*, num_indices : UInt, no_wrap_flags : LLVMM::GEPNoWrapFlags) : ValueRef
    fun gep_get_no_wrap_flags = LLVMGEPGetNoWrapFlags(gep : ValueRef) : LLVMM::GEPNoWrapFlags
    fun gep_set_no_wrap_flags = LLVMGEPSetNoWrapFlags(gep : ValueRef, no_wrap_flags : LLVMM::GEPNoWrapFlags)

    fun get_prefix_data = LLVMGetPrefixData(fn : ValueRef) : ValueRef
    fun set_prefix_data = LLVMSetPrefixData(fn : ValueRef, prefix_data : ValueRef)
    fun has_prefix_data = LLVMHasPrefixData(fn : ValueRef) : Bool
    fun get_prologue_data = LLVMGetPrologueData(fn : ValueRef) : ValueRef
    fun set_prologue_data = LLVMSetPrologueData(fn : ValueRef, prologue_data : ValueRef)
    fun has_prologue_data = LLVMHasPrologueData(fn : ValueRef) : Bool

    fun get_block_address_basic_block = LLVMGetBlockAddressBasicBlock(block_addr : ValueRef) : BasicBlockRef
    fun get_block_address_function = LLVMGetBlockAddressFunction(block_addr : ValueRef) : ValueRef

    fun create_constant_range_attribute = LLVMCreateConstantRangeAttribute(c : ContextRef, kind_id : UInt, num_bits : UInt, lower_words : UInt64*, upper_words : UInt64*) : AttributeRef

    fun position_builder_before_dbg_records = LLVMPositionBuilderBeforeDbgRecords(builder : BuilderRef, block : BasicBlockRef, inst : ValueRef)
    fun position_builder_before_instr_and_dbg_records = LLVMPositionBuilderBeforeInstrAndDbgRecords(builder : BuilderRef, instr : ValueRef)

    fun is_new_dbg_info_format = LLVMIsNewDbgInfoFormat(m : ModuleRef) : Bool
    fun set_is_new_dbg_info_format = LLVMSetIsNewDbgInfoFormat(m : ModuleRef, use_new_format : Bool)
    fun print_dbg_record_to_string = LLVMPrintDbgRecordToString(record : DbgRecordRef) : Char*

    fun constant_ptr_auth = LLVMConstantPtrAuth(ptr : ValueRef, key : ValueRef, disc : ValueRef, addr_disc : ValueRef) : ValueRef
  {% end %}

  {% unless LibLLVMM::IS_LT_200 %}
    fun build_atomicrmw_sync_scope = LLVMBuildAtomicRMWSyncScope(b : BuilderRef, op : LLVMM::AtomicRMWBinOp, ptr : ValueRef, val : ValueRef, ordering : LLVMM::AtomicOrdering, ssid : UInt) : ValueRef
    fun build_atomic_cmp_xchg_sync_scope = LLVMBuildAtomicCmpXchgSyncScope(b : BuilderRef, ptr : ValueRef, cmp : ValueRef, new : ValueRef, success_ordering : LLVMM::AtomicOrdering, failure_ordering : LLVMM::AtomicOrdering, ssid : UInt) : ValueRef
    fun build_fence_sync_scope = LLVMBuildFenceSyncScope(b : BuilderRef, ordering : LLVMM::AtomicOrdering, ssid : UInt, name : Char*) : ValueRef
    fun get_atomic_sync_scope_id = LLVMGetAtomicSyncScopeID(atomic_inst : ValueRef) : UInt
    fun set_atomic_sync_scope_id = LLVMSetAtomicSyncScopeID(atomic_inst : ValueRef, ssid : UInt)
    fun get_sync_scope_id = LLVMGetSyncScopeID(c : ContextRef, name : Char*, s_len : SizeT) : UInt

    fun get_builder_context = LLVMGetBuilderContext(builder : BuilderRef) : ContextRef
    fun get_value_context = LLVMGetValueContext(val : ValueRef) : ContextRef
    fun is_atomic = LLVMIsAtomic(inst : ValueRef) : Bool

    fun get_first_dbg_record = LLVMGetFirstDbgRecord(inst : ValueRef) : DbgRecordRef
    fun get_last_dbg_record = LLVMGetLastDbgRecord(inst : ValueRef) : DbgRecordRef
    fun get_next_dbg_record = LLVMGetNextDbgRecord(dbg_record : DbgRecordRef) : DbgRecordRef
    fun get_previous_dbg_record = LLVMGetPreviousDbgRecord(dbg_record : DbgRecordRef) : DbgRecordRef
  {% end %}

  {% unless LibLLVMM::IS_LT_210 %}
    fun get_icmp_same_sign = LLVMGetICmpSameSign(inst : ValueRef) : Bool
    fun set_icmp_same_sign = LLVMSetICmpSameSign(inst : ValueRef, same_sign : Bool)
    fun get_raw_data_values = LLVMGetRawDataValues(c : ValueRef, size_in_bytes : SizeT*) : Char*
  {% end %}

  {% unless LibLLVMM::IS_LT_220 %}
    fun const_fp_from_bits = LLVMConstFPFromBits(ty : TypeRef, n : UInt64*) : ValueRef
    fun get_switch_case_value = LLVMGetSwitchCaseValue(switch_instr : ValueRef, i : UInt) : ValueRef
    fun set_switch_case_value = LLVMSetSwitchCaseValue(switch_instr : ValueRef, i : UInt, case_value : ValueRef)
    fun global_add_debug_info = LLVMGlobalAddDebugInfo(global : ValueRef, gve : MetadataRef)
    fun global_add_metadata = LLVMGlobalAddMetadata(global : ValueRef, kind : UInt, md : MetadataRef)
  {% end %}

  {% unless LibLLVMM::IS_LT_230 %}
    fun byte_type_in_context = LLVMByteTypeInContext(c : ContextRef, num_bits : UInt) : TypeRef
    fun get_byte_type_width = LLVMGetByteTypeWidth(byte_ty : TypeRef) : UInt
    fun const_byte = LLVMConstByte(byte_ty : TypeRef, n : ULongLong) : ValueRef
    fun const_byte_get_sext_value = LLVMConstByteGetSExtValue(constant_val : ValueRef) : LongLong
    fun const_byte_get_zext_value = LLVMConstByteGetZExtValue(constant_val : ValueRef) : ULongLong
    fun const_byte_of_arbitrary_precision = LLVMConstByteOfArbitraryPrecision(byte_ty : TypeRef, num_words : UInt, words : UInt64*) : ValueRef
    fun const_byte_of_string_and_size = LLVMConstByteOfStringAndSize(byte_ty : TypeRef, text : Char*, s_len : SizeT, radix : UInt8) : ValueRef
    fun create_denormal_fp_env_attribute = LLVMCreateDenormalFPEnvAttribute(c : ContextRef, default_mode_output : LLVMM::DenormalModeKind, default_mode_input : LLVMM::DenormalModeKind, float_mode_output : LLVMM::DenormalModeKind, float_mode_input : LLVMM::DenormalModeKind) : AttributeRef
  {% end %}

  fun start_multithreaded = LLVMStartMultithreaded : Bool
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Bool
end
