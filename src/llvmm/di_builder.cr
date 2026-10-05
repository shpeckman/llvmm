# src/llvmm/di_builder.cr
require "./lib_llvm"

@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
struct LLVMM::DIBuilder
  private DW_TAG_structure_type = 19

  private def initialize(@unwrap : LibLLVMM::DIBuilderRef, @llvm_module : Module)
  end

  def self.new(mod : LLVMM::Module)
    new(LibLLVMM.create_di_builder(mod), mod)
  end

  def self.disallow_unresolved(mod : LLVMM::Module)
    new(LibLLVMM.create_di_builder_disallow_unresolved(mod), mod)
  end

  def dispose
    LibLLVMM.dispose_di_builder(self)
  end

  def context
    @llvm_module.context
  end

  def create_compile_unit(lang : DwarfSourceLanguage, file, dir, producer, optimized, flags, runtime_version)
    file = create_file(file, dir)
    LibLLVMM.di_builder_create_compile_unit(self,
      lang, file, producer, producer.bytesize, optimized ? 1 : 0, flags, flags.bytesize, runtime_version,
      split_name: nil, split_name_len: 0, kind: LibLLVMM::DWARFEmissionKind::Full, dwo_id: 0,
      split_debug_inlining: 1, debug_info_for_profiling: 0, sys_root: nil, sys_root_len: 0, sdk: nil, sdk_len: 0,
    )
  end

  def create_basic_type(name, size_in_bits, align_in_bits, encoding)
    LibLLVMM.di_builder_create_basic_type(self, name, name.bytesize, size_in_bits, encoding.value, DIFlags::Zero)
  end

  def get_or_create_type_array(types : Array(LibLLVMM::MetadataRef))
    LibLLVMM.di_builder_get_or_create_type_array(self, types, types.size)
  end

  def create_subroutine_type(file, parameter_types)
    LibLLVMM.di_builder_create_subroutine_type(self, file, parameter_types, parameter_types.size, DIFlags::Zero)
  end

  def create_file(file, dir)
    LibLLVMM.di_builder_create_file(self, file, file.bytesize, dir, dir.bytesize)
  end

  def create_lexical_block(scope, file_scope, line, column)
    LibLLVMM.di_builder_create_lexical_block(self, scope, file_scope, line, column)
  end

  def create_lexical_block_file(scope, file_scope, discriminator = 0)
    LibLLVMM.di_builder_create_lexical_block_file(self, scope, file_scope, discriminator)
  end

  def create_function(scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                      scope_line, flags, is_optimized, func)
    sub = LibLLVMM.di_builder_create_function(self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line, composite_type, is_local_to_unit ? 1 : 0,
      is_definition ? 1 : 0, scope_line, flags, is_optimized ? 1 : 0)
    LibLLVMM.set_subprogram(func, sub)
    sub
  end

  def create_auto_variable(scope, name, file, line, type, align_in_bits, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_auto_variable(self, scope, name, name.bytesize, file, line, type, 1, flags, align_in_bits)
  end

  def create_parameter_variable(scope, name, argno, file, line, type, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_parameter_variable(self, scope, name, name.bytesize, argno, file, line, type, 1, flags)
  end

  def create_global_variable_expression(scope, name, linkage_name, file, line, type, local_to_unit, expr = nil, decl = nil, align_in_bits = 0_u32)
    expr ||= create_expression(nil, 0)
    LibLLVMM.di_builder_create_global_variable_expression(
      self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line,
      type, local_to_unit, expr, decl, align_in_bits
    )
  end

  def create_expression(addr, length)
    LibLLVMM.di_builder_create_expression(self, addr, length)
  end

  def insert_declare_at_end(storage, var_info, expr, dl : LibLLVMM::MetadataRef, block)
    {% if LibLLVMM::IS_LT_190 %}
      LibLLVMM.di_builder_insert_declare_at_end(self, storage, var_info, expr, dl, block)
    {% else %}
      LibLLVMM.di_builder_insert_declare_record_at_end(self, storage, var_info, expr, dl, block)
    {% end %}
  end

  def get_or_create_array(elements : Array(LibLLVMM::MetadataRef))
    LibLLVMM.di_builder_get_or_create_array(self, elements, elements.size)
  end

  def create_enumerator(name, value)
    is_unsigned = value.is_a?(Int::Unsigned) ? 1 : 0

    {% unless LibLLVMM::IS_LT_210 %}
      if value.is_a?(Int128) || value.is_a?(UInt128)
        encoded_value = UInt64[value & UInt64::MAX, (value >> 64) & UInt64::MAX]
        return LibLLVMM.di_builder_create_enumerator_of_arbitrary_precision(
          self, name, name.bytesize, encoded_value.size * 64, encoded_value, is_unsigned)
      end
    {% end %}

    LibLLVMM.di_builder_create_enumerator(
      self, name, name.bytesize, value.to_i64!, is_unsigned)
  end

  def create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, elements, underlying_type)
    LibLLVMM.di_builder_create_enumeration_type(self, scope, name, name.bytesize, file, line_number,
      size_in_bits, align_in_bits, elements, elements.size, underlying_type)
  end

  def create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, element_types)
    LibLLVMM.di_builder_create_struct_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, derived_from, element_types, element_types.size, 0, nil, nil, 0)
  end

  def create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, element_types)
    LibLLVMM.di_builder_create_union_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, element_types, element_types.size, 0, nil, 0)
  end

  def create_array_type(size_in_bits, align_in_bits, type, subs)
    LibLLVMM.di_builder_create_array_type(self, size_in_bits, align_in_bits, type, subs, subs.size)
  end

  def create_member_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, ty)
    LibLLVMM.di_builder_create_member_type(self, scope, name, name.bytesize, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, ty)
  end

  def create_pointer_type(pointee, size_in_bits, align_in_bits, name)
    LibLLVMM.di_builder_create_pointer_type(self, pointee, size_in_bits, align_in_bits, 0, name, name.bytesize)
  end

  def create_replaceable_composite_type(scope, name, file, line)
    LibLLVMM.di_builder_create_replaceable_composite_type(self, DW_TAG_structure_type, name, name.bytesize,
      scope, file, line, 0, 0, 0, DIFlags::FwdDecl, nil, 0)
  end

  def replace_temporary(from, to)
    LibLLVMM.metadata_replace_all_uses_with(from, to)
  end

  def create_unspecified_type(name : String)
    LibLLVMM.di_builder_create_unspecified_type(self, name, name.bytesize)
  end

  def get_or_create_array_subrange(lo, count)
    LibLLVMM.di_builder_get_or_create_subrange(self, lo, count)
  end

  def create_debug_location(line, column, scope, inlined_at = nil)
    LibLLVMM.di_builder_create_debug_location(context, line, column, scope, inlined_at)
  end

  def finalize_subprogram(subprogram)
    LibLLVMM.di_builder_finalize_subprogram(self, subprogram)
  end

  def create_module(parent_scope, name, config_macros = "", include_path = "", api_notes_file = "")
    LibLLVMM.di_builder_create_module(self, parent_scope, name, name.bytesize,
      config_macros, config_macros.bytesize, include_path, include_path.bytesize,
      api_notes_file, api_notes_file.bytesize)
  end

  def create_namespace(parent_scope, name, export_symbols = false)
    LibLLVMM.di_builder_create_namespace(self, parent_scope, name, name.bytesize, export_symbols ? 1 : 0)
  end

  def create_imported_module_from_namespace(scope, ns, file, line)
    LibLLVMM.di_builder_create_imported_module_from_namespace(self, scope, ns, file, line)
  end

  def create_imported_module_from_alias(scope, imported_entity, file, line, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_module_from_alias(self, scope, imported_entity, file, line, elements, elements.size)
  end

  def create_imported_module_from_module(scope, mod, file, line, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_module_from_module(self, scope, mod, file, line, elements, elements.size)
  end

  def create_imported_declaration(scope, decl, file, line, name, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_declaration(self, scope, decl, file, line, name, name.bytesize, elements, elements.size)
  end

  def create_macro(parent_macro_file, line, record_type : DWARFMacinfoRecordType, name, value)
    LibLLVMM.di_builder_create_macro(self, parent_macro_file, line, record_type, name, name.bytesize, value, value.bytesize)
  end

  def create_temp_macro_file(parent_macro_file, line, file)
    LibLLVMM.di_builder_create_temp_macro_file(self, parent_macro_file, line, file)
  end

  def create_vector_type(size_in_bits, align_in_bits, type, subs)
    LibLLVMM.di_builder_create_vector_type(self, size_in_bits, align_in_bits, type, subs, subs.size)
  end

  def create_static_member_type(scope, name, file, line, type, flags = DIFlags::Zero, constant_val = nil, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_static_member_type(self, scope, name, name.bytesize, file, line, type, flags, constant_val, align_in_bits)
  end

  def create_member_pointer_type(pointee_type, class_type, size_in_bits, align_in_bits, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_member_pointer_type(self, pointee_type, class_type, size_in_bits, align_in_bits, flags)
  end

  def create_objc_ivar(name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, type, property_node = nil)
    LibLLVMM.di_builder_create_objc_ivar(self, name, name.bytesize, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, type, property_node)
  end

  def create_objc_property(name, file, line, getter_name, setter_name, property_attributes, type)
    LibLLVMM.di_builder_create_objc_property(self, name, name.bytesize, file, line,
      getter_name, getter_name.bytesize, setter_name, setter_name.bytesize, property_attributes, type)
  end

  def create_object_pointer_type(type, implicit = false)
    {% if LibLLVMM::IS_LT_200 %}
      LibLLVMM.di_builder_create_object_pointer_type(self, type)
    {% else %}
      LibLLVMM.di_builder_create_object_pointer_type(self, type, implicit ? 1 : 0)
    {% end %}
  end

  def create_qualified_type(tag, type)
    LibLLVMM.di_builder_create_qualified_type(self, tag, type)
  end

  def create_reference_type(tag, type)
    LibLLVMM.di_builder_create_reference_type(self, tag, type)
  end

  def create_nullptr_type
    LibLLVMM.di_builder_create_nullptr_type(self)
  end

  def create_typedef(type, name, file, line, scope, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_typedef(self, type, name, name.bytesize, file, line, scope, align_in_bits)
  end

  def create_inheritance(ty, base_ty, base_offset, vb_ptr_offset = 0_u32, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_inheritance(self, ty, base_ty, base_offset, vb_ptr_offset, flags)
  end

  def create_forward_decl(tag, name, scope, file, line, runtime_lang = 0, size_in_bits = 0_u64, align_in_bits = 0_u32, unique_id = "")
    LibLLVMM.di_builder_create_forward_decl(self, tag, name, name.bytesize, scope, file, line,
      runtime_lang, size_in_bits, align_in_bits, unique_id, unique_id.bytesize)
  end

  def create_bitfield_member_type(scope, name, file, line, size_in_bits, offset_in_bits, storage_offset_in_bits, flags, type)
    LibLLVMM.di_builder_create_bitfield_member_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, offset_in_bits, storage_offset_in_bits, flags, type)
  end

  def create_class_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, derived_from,
                        element_types, vtable_holder = nil, template_params = nil, unique_id = "")
    LibLLVMM.di_builder_create_class_type(self, scope, name, name.bytesize, file, line, size_in_bits,
      align_in_bits, offset_in_bits, flags, derived_from, element_types, element_types.size,
      vtable_holder, template_params, unique_id, unique_id.bytesize)
  end

  def create_artificial_type(type)
    LibLLVMM.di_builder_create_artificial_type(self, type)
  end

  def create_constant_value_expression(value : UInt64)
    LibLLVMM.di_builder_create_constant_value_expression(self, value)
  end

  def create_temp_global_variable_fwd_decl(scope, name, linkage_name, file, line, type, local_to_unit, decl = nil, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_temp_global_variable_fwd_decl(self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line, type, local_to_unit ? 1 : 0, decl, align_in_bits)
  end

  def end
    LibLLVMM.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
