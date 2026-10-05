# src/llvmm/lib_llvm/debug_info.cr
require "./types"

lib LibLLVMM
  enum DWARFEmissionKind
    Full = 1
  end

  fun create_di_builder = LLVMCreateDIBuilder(m : ModuleRef) : DIBuilderRef
  fun dispose_di_builder = LLVMDisposeDIBuilder(builder : DIBuilderRef)
  fun di_builder_finalize = LLVMDIBuilderFinalize(builder : DIBuilderRef)

  fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
    builder : DIBuilderRef, lang : LLVMM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
    producer_len : SizeT, is_optimized : Bool, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
    split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
    split_debug_inlining : Bool, debug_info_for_profiling : Bool, sys_root : Char*,
    sys_root_len : SizeT, sdk : Char*, sdk_len : SizeT,
  ) : MetadataRef

  fun di_builder_create_file = LLVMDIBuilderCreateFile(
    builder : DIBuilderRef, filename : Char*, filename_len : SizeT,
    directory : Char*, directory_len : SizeT,
  ) : MetadataRef

  fun di_builder_create_function = LLVMDIBuilderCreateFunction(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
    linkage_name : Char*, linkage_name_len : SizeT, file : MetadataRef, line_no : UInt,
    ty : MetadataRef, is_local_to_unit : Bool, is_definition : Bool, scope_line : UInt,
    flags : LLVMM::DIFlags, is_optimized : Bool,
  ) : MetadataRef

  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(
    builder : DIBuilderRef, scope : MetadataRef, file : MetadataRef, line : UInt, column : UInt,
  ) : MetadataRef
  fun di_builder_create_lexical_block_file = LLVMDIBuilderCreateLexicalBlockFile(
    builder : DIBuilderRef, scope : MetadataRef, file_scope : MetadataRef, discriminator : UInt,
  ) : MetadataRef

  fun di_builder_create_debug_location = LLVMDIBuilderCreateDebugLocation(
    ctx : ContextRef, line : UInt, column : UInt, scope : MetadataRef, inlined_at : MetadataRef,
  ) : MetadataRef

  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilderRef, types : MetadataRef*, length : SizeT) : MetadataRef

  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(
    builder : DIBuilderRef, file : MetadataRef, parameter_types : MetadataRef*,
    num_parameter_types : UInt, flags : LLVMM::DIFlags,
  ) : MetadataRef
  fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, value : Int64, is_unsigned : Bool,
  ) : MetadataRef
  {% unless LibLLVMM::IS_LT_210 %}
    fun di_builder_create_enumerator_of_arbitrary_precision = LLVMDIBuilderCreateEnumeratorOfArbitraryPrecision(
      builder : DIBuilderRef, name : Char*, name_len : SizeT, size_in_bits : UInt64, words : UInt64*, is_unsigned : Bool,
    ) : MetadataRef
  {% end %}
  fun di_builder_create_enumeration_type = LLVMDIBuilderCreateEnumerationType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    elements : MetadataRef*, num_elements : UInt, class_ty : MetadataRef,
  ) : MetadataRef
  fun di_builder_create_union_type = LLVMDIBuilderCreateUnionType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVMM::DIFlags,
    elements : MetadataRef*, num_elements : UInt, run_time_lang : UInt, unique_id : Char*, unique_id_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_array_type = LLVMDIBuilderCreateArrayType(
    builder : DIBuilderRef, size : UInt64, align_in_bits : UInt32,
    ty : MetadataRef, subscripts : MetadataRef*, num_subscripts : UInt,
  ) : MetadataRef
  fun di_builder_create_unspecified_type = LLVMDIBuilderCreateUnspecifiedType(builder : DIBuilderRef, name : Char*, name_len : SizeT) : MetadataRef
  fun di_builder_create_basic_type = LLVMDIBuilderCreateBasicType(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, size_in_bits : UInt64,
    encoding : UInt, flags : LLVMM::DIFlags,
  ) : MetadataRef
  fun di_builder_create_pointer_type = LLVMDIBuilderCreatePointerType(
    builder : DIBuilderRef, pointee_ty : MetadataRef, size_in_bits : UInt64, align_in_bits : UInt32,
    address_space : UInt, name : Char*, name_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_struct_type = LLVMDIBuilderCreateStructType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVMM::DIFlags,
    derived_from : MetadataRef, elements : MetadataRef*, num_elements : UInt,
    run_time_lang : UInt, v_table_holder : MetadataRef, unique_id : Char*, unique_id_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_member_type = LLVMDIBuilderCreateMemberType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, size_in_bits : UInt64, align_in_bits : UInt32, offset_in_bits : UInt64,
    flags : LLVMM::DIFlags, ty : MetadataRef,
  ) : MetadataRef
  fun di_builder_create_replaceable_composite_type = LLVMDIBuilderCreateReplaceableCompositeType(
    builder : DIBuilderRef, tag : UInt, name : Char*, name_len : SizeT, scope : MetadataRef,
    file : MetadataRef, line : UInt, runtime_lang : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    flags : LLVMM::DIFlags, unique_identifier : Char*, unique_identifier_len : SizeT,
  ) : MetadataRef

  fun di_builder_get_or_create_subrange = LLVMDIBuilderGetOrCreateSubrange(builder : DIBuilderRef, lo : Int64, count : Int64) : MetadataRef
  fun di_builder_get_or_create_array = LLVMDIBuilderGetOrCreateArray(builder : DIBuilderRef, data : MetadataRef*, length : SizeT) : MetadataRef

  fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : UInt64*, length : SizeT) : MetadataRef

  fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(target_metadata : MetadataRef, replacement : MetadataRef)

  {% if LibLLVMM::IS_LT_190 %}
    fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(
      builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
      expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef,
    ) : ValueRef
  {% else %}
    fun di_builder_insert_declare_record_at_end = LLVMDIBuilderInsertDeclareRecordAtEnd(
      builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
      expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef,
    ) : DbgRecordRef

    fun di_builder_insert_declare_record_before = LLVMDIBuilderInsertDeclareRecordBefore(
      builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
      expr : MetadataRef, debug_loc : MetadataRef, instr : ValueRef,
    ) : DbgRecordRef

    fun di_builder_insert_dbg_value_record_at_end = LLVMDIBuilderInsertDbgValueRecordAtEnd(
      builder : DIBuilderRef, val : ValueRef, var_info : MetadataRef,
      expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef,
    ) : DbgRecordRef

    fun di_builder_insert_dbg_value_record_before = LLVMDIBuilderInsertDbgValueRecordBefore(
      builder : DIBuilderRef, val : ValueRef, var_info : MetadataRef,
      expr : MetadataRef, debug_loc : MetadataRef, instr : ValueRef,
    ) : DbgRecordRef
  {% end %}

  {% unless LibLLVMM::IS_LT_200 %}
    fun di_builder_create_label = LLVMDIBuilderCreateLabel(
      builder : DIBuilderRef, context : MetadataRef, name : Char*, name_len : SizeT,
      file : MetadataRef, line_no : UInt, always_preserve : Bool,
    ) : MetadataRef

    fun di_builder_insert_label_at_end = LLVMDIBuilderInsertLabelAtEnd(
      builder : DIBuilderRef, label_info : MetadataRef, location : MetadataRef, insert_at_end : BasicBlockRef,
    ) : DbgRecordRef

    fun di_builder_insert_label_before = LLVMDIBuilderInsertLabelBefore(
      builder : DIBuilderRef, label_info : MetadataRef, location : MetadataRef, insert_before : ValueRef,
    ) : DbgRecordRef
  {% end %}

  {% unless LibLLVMM::IS_LT_210 %}
    fun di_builder_create_dynamic_array_type = LLVMDIBuilderCreateDynamicArrayType(
      builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
      line_no : UInt, file : MetadataRef, size : UInt64, align_in_bits : UInt32,
      ty : MetadataRef, subscripts : MetadataRef*, num_subscripts : UInt,
      data_location : MetadataRef, associated : MetadataRef, allocated : MetadataRef,
      rank : MetadataRef, bit_stride : MetadataRef,
    ) : MetadataRef

    fun di_builder_create_set_type = LLVMDIBuilderCreateSetType(
      builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
      file : MetadataRef, line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
      base_ty : MetadataRef,
    ) : MetadataRef

    fun di_builder_create_subrange_type = LLVMDIBuilderCreateSubrangeType(
      builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
      line_no : UInt, file : MetadataRef, size_in_bits : UInt64, align_in_bits : UInt32,
      flags : LLVMM::DIFlags, base_ty : MetadataRef, lower_bound : MetadataRef,
      upper_bound : MetadataRef, stride : MetadataRef, bias : MetadataRef,
    ) : MetadataRef

    fun di_subprogram_replace_type = LLVMDISubprogramReplaceType(subprogram : MetadataRef, subroutine_type : MetadataRef)

    fun replace_arrays = LLVMReplaceArrays(builder : DIBuilderRef, t : MetadataRef*, elements : MetadataRef*, num_elements : UInt)
  {% end %}

  {% unless LibLLVMM::IS_LT_220 %}
    fun di_builder_create_file_with_checksum = LLVMDIBuilderCreateFileWithChecksum(
      builder : DIBuilderRef, filename : Char*, filename_len : SizeT,
      directory : Char*, directory_len : SizeT, checksum_kind : LLVMM::ChecksumKind,
      checksum : Char*, checksum_len : SizeT, source : Char*, source_len : SizeT,
    ) : MetadataRef

    fun dbg_record_get_debug_loc = LLVMDbgRecordGetDebugLoc(rec : DbgRecordRef) : MetadataRef
    fun dbg_record_get_kind = LLVMDbgRecordGetKind(rec : DbgRecordRef) : LLVMM::DbgRecordKind
    fun dbg_variable_record_get_value = LLVMDbgVariableRecordGetValue(rec : DbgRecordRef, op_idx : UInt) : ValueRef
    fun dbg_variable_record_get_variable = LLVMDbgVariableRecordGetVariable(rec : DbgRecordRef) : MetadataRef
    fun dbg_variable_record_get_expression = LLVMDbgVariableRecordGetExpression(rec : DbgRecordRef) : MetadataRef
  {% end %}

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, ty : MetadataRef, always_preserve : Bool, flags : LLVMM::DIFlags, align_in_bits : UInt32,
  ) : MetadataRef
  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, arg_no : UInt,
    file : MetadataRef, line_no : UInt, ty : MetadataRef, always_preserve : Bool, flags : LLVMM::DIFlags,
  ) : MetadataRef

  fun di_builder_create_global_variable_expression = LLVMDIBuilderCreateGlobalVariableExpression(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
    linkage : Char*, linkage_len : SizeT, file : MetadataRef, line_no : UInt,
    ty : MetadataRef, local_to_unit : Bool, expr : MetadataRef, decl : MetadataRef, align_in_bits : UInt32,
  ) : MetadataRef

  fun set_subprogram = LLVMSetSubprogram(func : ValueRef, sp : MetadataRef)
  fun get_subprogram = LLVMGetSubprogram(func : ValueRef) : MetadataRef

  fun debug_metadata_version = LLVMDebugMetadataVersion : UInt
  fun get_module_debug_metadata_version = LLVMGetModuleDebugMetadataVersion(mod : ModuleRef) : UInt
  fun strip_module_debug_info = LLVMStripModuleDebugInfo(mod : ModuleRef) : Bool

  fun create_di_builder_disallow_unresolved = LLVMCreateDIBuilderDisallowUnresolved(m : ModuleRef) : DIBuilderRef
  fun di_builder_finalize_subprogram = LLVMDIBuilderFinalizeSubprogram(builder : DIBuilderRef, subprogram : MetadataRef)

  fun di_builder_create_module = LLVMDIBuilderCreateModule(
    builder : DIBuilderRef, parent_scope : MetadataRef, name : Char*, name_len : SizeT,
    config_macros : Char*, config_macros_len : SizeT, include_path : Char*, include_path_len : SizeT,
    api_notes_file : Char*, api_notes_file_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_namespace = LLVMDIBuilderCreateNameSpace(
    builder : DIBuilderRef, parent_scope : MetadataRef, name : Char*, name_len : SizeT, export_symbols : Bool,
  ) : MetadataRef

  fun di_builder_create_imported_module_from_namespace = LLVMDIBuilderCreateImportedModuleFromNamespace(
    builder : DIBuilderRef, scope : MetadataRef, ns : MetadataRef, file : MetadataRef, line : UInt,
  ) : MetadataRef
  fun di_builder_create_imported_module_from_alias = LLVMDIBuilderCreateImportedModuleFromAlias(
    builder : DIBuilderRef, scope : MetadataRef, imported_entity : MetadataRef, file : MetadataRef,
    line : UInt, elements : MetadataRef*, num_elements : UInt,
  ) : MetadataRef
  fun di_builder_create_imported_module_from_module = LLVMDIBuilderCreateImportedModuleFromModule(
    builder : DIBuilderRef, scope : MetadataRef, m : MetadataRef, file : MetadataRef,
    line : UInt, elements : MetadataRef*, num_elements : UInt,
  ) : MetadataRef
  fun di_builder_create_imported_declaration = LLVMDIBuilderCreateImportedDeclaration(
    builder : DIBuilderRef, scope : MetadataRef, decl : MetadataRef, file : MetadataRef,
    line : UInt, name : Char*, name_len : SizeT, elements : MetadataRef*, num_elements : UInt,
  ) : MetadataRef

  fun di_location_get_line = LLVMDILocationGetLine(location : MetadataRef) : UInt
  fun di_location_get_column = LLVMDILocationGetColumn(location : MetadataRef) : UInt
  fun di_location_get_scope = LLVMDILocationGetScope(location : MetadataRef) : MetadataRef
  fun di_location_get_inlined_at = LLVMDILocationGetInlinedAt(location : MetadataRef) : MetadataRef
  fun di_scope_get_file = LLVMDIScopeGetFile(scope : MetadataRef) : MetadataRef
  fun di_file_get_directory = LLVMDIFileGetDirectory(file : MetadataRef, len : UInt*) : Char*
  fun di_file_get_filename = LLVMDIFileGetFilename(file : MetadataRef, len : UInt*) : Char*
  fun di_file_get_source = LLVMDIFileGetSource(file : MetadataRef, len : UInt*) : Char*

  fun di_builder_create_macro = LLVMDIBuilderCreateMacro(
    builder : DIBuilderRef, parent_macro_file : MetadataRef, line : UInt,
    record_type : LLVMM::DWARFMacinfoRecordType, name : Char*, name_len : SizeT, value : Char*, value_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_temp_macro_file = LLVMDIBuilderCreateTempMacroFile(
    builder : DIBuilderRef, parent_macro_file : MetadataRef, line : UInt, file : MetadataRef,
  ) : MetadataRef

  fun di_builder_create_vector_type = LLVMDIBuilderCreateVectorType(
    builder : DIBuilderRef, size : UInt64, align_in_bits : UInt32,
    ty : MetadataRef, subscripts : MetadataRef*, num_subscripts : UInt,
  ) : MetadataRef
  fun di_builder_create_static_member_type = LLVMDIBuilderCreateStaticMemberType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, type : MetadataRef, flags : LLVMM::DIFlags, constant_val : ValueRef, align_in_bits : UInt32,
  ) : MetadataRef
  fun di_builder_create_member_pointer_type = LLVMDIBuilderCreateMemberPointerType(
    builder : DIBuilderRef, pointee_type : MetadataRef, class_type : MetadataRef,
    size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVMM::DIFlags,
  ) : MetadataRef
  fun di_builder_create_objc_ivar = LLVMDIBuilderCreateObjCIVar(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, file : MetadataRef, line_no : UInt,
    size_in_bits : UInt64, align_in_bits : UInt32, offset_in_bits : UInt64, flags : LLVMM::DIFlags,
    ty : MetadataRef, property_node : MetadataRef,
  ) : MetadataRef
  fun di_builder_create_objc_property = LLVMDIBuilderCreateObjCProperty(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, file : MetadataRef, line_no : UInt,
    getter_name : Char*, getter_name_len : SizeT, setter_name : Char*, setter_name_len : SizeT,
    property_attributes : UInt, ty : MetadataRef,
  ) : MetadataRef
  {% if LibLLVMM::IS_LT_200 %}
    fun di_builder_create_object_pointer_type = LLVMDIBuilderCreateObjectPointerType(builder : DIBuilderRef, type : MetadataRef) : MetadataRef
  {% else %}
    fun di_builder_create_object_pointer_type = LLVMDIBuilderCreateObjectPointerType(builder : DIBuilderRef, type : MetadataRef, implicit : Bool) : MetadataRef
  {% end %}
  fun di_builder_create_qualified_type = LLVMDIBuilderCreateQualifiedType(builder : DIBuilderRef, tag : UInt, type : MetadataRef) : MetadataRef
  fun di_builder_create_reference_type = LLVMDIBuilderCreateReferenceType(builder : DIBuilderRef, tag : UInt, type : MetadataRef) : MetadataRef
  fun di_builder_create_nullptr_type = LLVMDIBuilderCreateNullPtrType(builder : DIBuilderRef) : MetadataRef
  fun di_builder_create_typedef = LLVMDIBuilderCreateTypedef(
    builder : DIBuilderRef, type : MetadataRef, name : Char*, name_len : SizeT,
    file : MetadataRef, line_no : UInt, scope : MetadataRef, align_in_bits : UInt32,
  ) : MetadataRef
  fun di_builder_create_inheritance = LLVMDIBuilderCreateInheritance(
    builder : DIBuilderRef, ty : MetadataRef, base_ty : MetadataRef,
    base_offset : UInt64, vb_ptr_offset : UInt32, flags : LLVMM::DIFlags,
  ) : MetadataRef
  fun di_builder_create_forward_decl = LLVMDIBuilderCreateForwardDecl(
    builder : DIBuilderRef, tag : UInt, name : Char*, name_len : SizeT, scope : MetadataRef,
    file : MetadataRef, line : UInt, runtime_lang : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    unique_identifier : Char*, unique_identifier_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_bitfield_member_type = LLVMDIBuilderCreateBitFieldMemberType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, offset_in_bits : UInt64, storage_offset_in_bits : UInt64,
    flags : LLVMM::DIFlags, type : MetadataRef,
  ) : MetadataRef
  fun di_builder_create_class_type = LLVMDIBuilderCreateClassType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, offset_in_bits : UInt64,
    flags : LLVMM::DIFlags, derived_from : MetadataRef, elements : MetadataRef*, num_elements : UInt,
    vtable_holder : MetadataRef, template_params_node : MetadataRef,
    unique_identifier : Char*, unique_identifier_len : SizeT,
  ) : MetadataRef
  fun di_builder_create_artificial_type = LLVMDIBuilderCreateArtificialType(builder : DIBuilderRef, type : MetadataRef) : MetadataRef

  fun di_type_get_name = LLVMDITypeGetName(dtype : MetadataRef, length : SizeT*) : Char*
  fun di_type_get_size_in_bits = LLVMDITypeGetSizeInBits(dtype : MetadataRef) : UInt64
  fun di_type_get_offset_in_bits = LLVMDITypeGetOffsetInBits(dtype : MetadataRef) : UInt64
  fun di_type_get_align_in_bits = LLVMDITypeGetAlignInBits(dtype : MetadataRef) : UInt32
  fun di_type_get_line = LLVMDITypeGetLine(dtype : MetadataRef) : UInt
  fun di_type_get_flags = LLVMDITypeGetFlags(dtype : MetadataRef) : LLVMM::DIFlags

  fun di_builder_create_constant_value_expression = LLVMDIBuilderCreateConstantValueExpression(builder : DIBuilderRef, value : UInt64) : MetadataRef

  fun get_di_node_tag = LLVMGetDINodeTag(md : MetadataRef) : UInt16
  fun di_global_variable_expression_get_variable = LLVMDIGlobalVariableExpressionGetVariable(gve : MetadataRef) : MetadataRef
  fun di_global_variable_expression_get_expression = LLVMDIGlobalVariableExpressionGetExpression(gve : MetadataRef) : MetadataRef
  fun di_variable_get_file = LLVMDIVariableGetFile(var : MetadataRef) : MetadataRef
  fun di_variable_get_scope = LLVMDIVariableGetScope(var : MetadataRef) : MetadataRef
  fun di_variable_get_line = LLVMDIVariableGetLine(var : MetadataRef) : UInt
  fun di_subprogram_get_line = LLVMDISubprogramGetLine(subprogram : MetadataRef) : UInt

  fun temporary_md_node = LLVMTemporaryMDNode(ctx : ContextRef, data : MetadataRef*, num_elements : SizeT) : MetadataRef
  fun dispose_temporary_md_node = LLVMDisposeTemporaryMDNode(temp_node : MetadataRef)

  fun di_builder_create_temp_global_variable_fwd_decl = LLVMDIBuilderCreateTempGlobalVariableFwdDecl(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
    linkage : Char*, linkage_len : SizeT, file : MetadataRef, line_no : UInt, ty : MetadataRef,
    local_to_unit : Bool, decl : MetadataRef, align_in_bits : UInt32,
  ) : MetadataRef

  fun instruction_get_debug_loc = LLVMInstructionGetDebugLoc(inst : ValueRef) : MetadataRef
  fun instruction_set_debug_loc = LLVMInstructionSetDebugLoc(inst : ValueRef, loc : MetadataRef)

  fun get_metadata_kind = LLVMGetMetadataKind(metadata : MetadataRef) : LLVMM::MetadataKind
end
