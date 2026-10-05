# src/llvmm/di_builder.cr
require "./lib_llvm"

@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
# Builds DWARF debug-info metadata for an `LLVMM::Module` (wraps
# `LLVMDIBuilder`).
#
# Being a `struct`, it has no GC finalizer: call `#dispose` when the
# builder is no longer needed, otherwise the underlying LLVM object leaks.
# Call `#end` once all metadata has been created to finalize the debug
# info before the module is verified or emitted.
struct LLVMM::DIBuilder
  private DW_TAG_structure_type = 19

  private def initialize(@unwrap : LibLLVMM::DIBuilderRef, @llvm_module : Module)
  end

  # Creates a builder for *mod*.
  def self.new(mod : LLVMM::Module)
    new(LibLLVMM.create_di_builder(mod), mod)
  end

  # Creates a builder for *mod* that reports unresolved temporary metadata
  # nodes when `#end` finalizes the debug info, instead of silently
  # resolving them.
  def self.disallow_unresolved(mod : LLVMM::Module)
    new(LibLLVMM.create_di_builder_disallow_unresolved(mod), mod)
  end

  # Disposes the builder. Not called automatically; see the type
  # documentation.
  def dispose
    LibLLVMM.dispose_di_builder(self)
  end

  # The context of the module this builder was created for.
  def context
    @llvm_module.context
  end

  # Creates the compile unit (full DWARF emission). *producer* identifies
  # the compiler that generated the module.
  def create_compile_unit(lang : DwarfSourceLanguage, file, dir, producer, optimized, flags, runtime_version)
    file = create_file(file, dir)
    LibLLVMM.di_builder_create_compile_unit(self,
      lang, file, producer, producer.bytesize, optimized ? 1 : 0, flags, flags.bytesize, runtime_version,
      split_name: nil, split_name_len: 0, kind: LibLLVMM::DWARFEmissionKind::Full, dwo_id: 0,
      split_debug_inlining: 1, debug_info_for_profiling: 0, sys_root: nil, sys_root_len: 0, sdk: nil, sdk_len: 0,
    )
  end

  # Creates a `DIBasicType` (e.g. an integer or float type).
  #
  # NOTE: *align_in_bits* is currently ignored; the wrapped C API call
  # does not take an alignment argument.
  def create_basic_type(name, size_in_bits, align_in_bits, encoding)
    LibLLVMM.di_builder_create_basic_type(self, name, name.bytesize, size_in_bits, encoding.value, DIFlags::Zero)
  end

  # Returns an array metadata node wrapping *types*, suitable as the
  # parameter list of `#create_subroutine_type`.
  def get_or_create_type_array(types : Array(LibLLVMM::MetadataRef))
    LibLLVMM.di_builder_get_or_create_type_array(self, types, types.size)
  end

  # Creates a subroutine (function signature) type.
  def create_subroutine_type(file, parameter_types)
    LibLLVMM.di_builder_create_subroutine_type(self, file, parameter_types, parameter_types.size, DIFlags::Zero)
  end

  # Creates a `DIFile` for *file* in directory *dir*.
  def create_file(file, dir)
    LibLLVMM.di_builder_create_file(self, file, file.bytesize, dir, dir.bytesize)
  end

  # Creates a lexical block scope.
  def create_lexical_block(scope, file_scope, line, column)
    LibLLVMM.di_builder_create_lexical_block(self, scope, file_scope, line, column)
  end

  # Creates a lexical block scope with a file discriminator, used to
  # distinguish identical line/column locations across inlined files.
  def create_lexical_block_file(scope, file_scope, discriminator = 0)
    LibLLVMM.di_builder_create_lexical_block_file(self, scope, file_scope, discriminator)
  end

  # Creates a `DISubprogram` describing a function and attaches it to
  # *func*. Returns the new subprogram metadata node.
  def create_function(scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                      scope_line, flags, is_optimized, func)
    sub = LibLLVMM.di_builder_create_function(self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line, composite_type, is_local_to_unit ? 1 : 0,
      is_definition ? 1 : 0, scope_line, flags, is_optimized ? 1 : 0)
    LibLLVMM.set_subprogram(func, sub)
    sub
  end

  # Creates a `DILocalVariable` for a stack variable; the variable is
  # always preserved, even in optimized code.
  def create_auto_variable(scope, name, file, line, type, align_in_bits, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_auto_variable(self, scope, name, name.bytesize, file, line, type, 1, flags, align_in_bits)
  end

  # Creates a `DILocalVariable` for the *argno*-th (1-based) function
  # parameter.
  def create_parameter_variable(scope, name, argno, file, line, type, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_parameter_variable(self, scope, name, name.bytesize, argno, file, line, type, 1, flags)
  end

  # Creates a `DIGlobalVariableExpression`; attach it to a global with
  # `global_set_metadata`. Defaults to an empty *expr* when none is given.
  def create_global_variable_expression(scope, name, linkage_name, file, line, type, local_to_unit, expr = nil, decl = nil, align_in_bits = 0_u32)
    expr ||= create_expression(nil, 0)
    LibLLVMM.di_builder_create_global_variable_expression(
      self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line,
      type, local_to_unit, expr, decl, align_in_bits
    )
  end

  # Creates a `DIExpression` from *addr* (an array of `UInt64` DWARF
  # expression operands, or `nil` for an empty expression).
  def create_expression(addr, length)
    LibLLVMM.di_builder_create_expression(self, addr, length)
  end

  # Inserts a debug-info declare for *storage* (typically an `alloca`) at
  # the end of *block*.
  #
  # On LLVM 19 and later this emits a debug record instead of the legacy
  # `llvm.dbg.declare` intrinsic.
  def insert_declare_at_end(storage, var_info, expr, dl : LibLLVMM::MetadataRef, block)
    {% if LibLLVMM::IS_LT_190 %}
      LibLLVMM.di_builder_insert_declare_at_end(self, storage, var_info, expr, dl, block)
    {% else %}
      LibLLVMM.di_builder_insert_declare_record_at_end(self, storage, var_info, expr, dl, block)
    {% end %}
  end

  # Returns an array metadata node wrapping *elements*.
  def get_or_create_array(elements : Array(LibLLVMM::MetadataRef))
    LibLLVMM.di_builder_get_or_create_array(self, elements, elements.size)
  end

  # Creates a `DIEnumerator` with the given *value*.
  #
  # On LLVM 21 and later, 128-bit values (`Int128`/`UInt128`) are
  # supported through the arbitrary-precision API; on earlier versions
  # they raise `TypeCastError` via `to_i64!`.
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

  # Creates an enumeration type from *elements* (created with
  # `#create_enumerator`) and *underlying_type*.
  def create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, elements, underlying_type)
    LibLLVMM.di_builder_create_enumeration_type(self, scope, name, name.bytesize, file, line_number,
      size_in_bits, align_in_bits, elements, elements.size, underlying_type)
  end

  # Creates a struct type from *element_types* (created with
  # `#create_member_type`).
  def create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, element_types)
    LibLLVMM.di_builder_create_struct_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, derived_from, element_types, element_types.size, 0, nil, nil, 0)
  end

  # Creates a union type from *element_types* (created with
  # `#create_member_type`).
  def create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, element_types)
    LibLLVMM.di_builder_create_union_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, element_types, element_types.size, 0, nil, 0)
  end

  # Creates an array type with the given element *type* and *subs*
  # (subranges created with `#get_or_create_array_subrange`).
  def create_array_type(size_in_bits, align_in_bits, type, subs)
    LibLLVMM.di_builder_create_array_type(self, size_in_bits, align_in_bits, type, subs, subs.size)
  end

  # Creates a member (field) type at *offset_in_bits* within its
  # composite type.
  def create_member_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, ty)
    LibLLVMM.di_builder_create_member_type(self, scope, name, name.bytesize, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, ty)
  end

  # Creates a pointer type to *pointee*.
  def create_pointer_type(pointee, size_in_bits, align_in_bits, name)
    LibLLVMM.di_builder_create_pointer_type(self, pointee, size_in_bits, align_in_bits, 0, name, name.bytesize)
  end

  # Creates a temporary forward-declared struct type to be replaced later
  # with `#replace_temporary` (e.g. for self-referential types).
  def create_replaceable_composite_type(scope, name, file, line)
    LibLLVMM.di_builder_create_replaceable_composite_type(self, DW_TAG_structure_type, name, name.bytesize,
      scope, file, line, 0, 0, 0, DIFlags::FwdDecl, nil, 0)
  end

  # Replaces all uses of the temporary node *from* with *to* (see
  # `#create_replaceable_composite_type`).
  def replace_temporary(from, to)
    LibLLVMM.metadata_replace_all_uses_with(from, to)
  end

  # Creates an opaque/unspecified type (e.g. for forward declarations
  # that are never completed).
  def create_unspecified_type(name : String)
    LibLLVMM.di_builder_create_unspecified_type(self, name, name.bytesize)
  end

  # Returns a subrange metadata node describing *count* elements starting
  # at *lo*, for use with `#create_array_type`.
  def get_or_create_array_subrange(lo, count)
    LibLLVMM.di_builder_get_or_create_subrange(self, lo, count)
  end

  # Creates a `DILocation` for the given *line* and *column* in *scope*.
  def create_debug_location(line, column, scope, inlined_at = nil)
    LibLLVMM.di_builder_create_debug_location(context, line, column, scope, inlined_at)
  end

  # Finalizes *subprogram* metadata; required before `#end` when the
  # subprogram was created from temporary nodes.
  def finalize_subprogram(subprogram)
    LibLLVMM.di_builder_finalize_subprogram(self, subprogram)
  end

  # Creates a `DIModule` (e.g. for languages with module systems).
  def create_module(parent_scope, name, config_macros = "", include_path = "", api_notes_file = "")
    LibLLVMM.di_builder_create_module(self, parent_scope, name, name.bytesize,
      config_macros, config_macros.bytesize, include_path, include_path.bytesize,
      api_notes_file, api_notes_file.bytesize)
  end

  # Creates a `DINamespace`.
  def create_namespace(parent_scope, name, export_symbols = false)
    LibLLVMM.di_builder_create_namespace(self, parent_scope, name, name.bytesize, export_symbols ? 1 : 0)
  end

  # Creates an imported-module node importing namespace *ns* into *scope*.
  def create_imported_module_from_namespace(scope, ns, file, line)
    LibLLVMM.di_builder_create_imported_module_from_namespace(self, scope, ns, file, line)
  end

  # Creates an imported-module node importing the alias *imported_entity*
  # into *scope*.
  def create_imported_module_from_alias(scope, imported_entity, file, line, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_module_from_alias(self, scope, imported_entity, file, line, elements, elements.size)
  end

  # Creates an imported-module node importing module *mod* into *scope*.
  def create_imported_module_from_module(scope, mod, file, line, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_module_from_module(self, scope, mod, file, line, elements, elements.size)
  end

  # Creates a node importing the declaration *decl* into *scope* under
  # *name*.
  def create_imported_declaration(scope, decl, file, line, name, elements = [] of LibLLVMM::MetadataRef)
    LibLLVMM.di_builder_create_imported_declaration(self, scope, decl, file, line, name, name.bytesize, elements, elements.size)
  end

  # Creates a macro debug-info node.
  def create_macro(parent_macro_file, line, record_type : DWARFMacinfoRecordType, name, value)
    LibLLVMM.di_builder_create_macro(self, parent_macro_file, line, record_type, name, name.bytesize, value, value.bytesize)
  end

  # Creates a temporary macro file node, replaced once the real file node
  # is known.
  def create_temp_macro_file(parent_macro_file, line, file)
    LibLLVMM.di_builder_create_temp_macro_file(self, parent_macro_file, line, file)
  end

  # Creates a vector type with the given element *type* and *subs*
  # (subranges created with `#get_or_create_array_subrange`).
  def create_vector_type(size_in_bits, align_in_bits, type, subs)
    LibLLVMM.di_builder_create_vector_type(self, size_in_bits, align_in_bits, type, subs, subs.size)
  end

  # Creates a static (class-level) member type, optionally with a
  # *constant_val*.
  def create_static_member_type(scope, name, file, line, type, flags = DIFlags::Zero, constant_val = nil, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_static_member_type(self, scope, name, name.bytesize, file, line, type, flags, constant_val, align_in_bits)
  end

  # Creates a pointer-to-member type for members of *class_type*.
  def create_member_pointer_type(pointee_type, class_type, size_in_bits, align_in_bits, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_member_pointer_type(self, pointee_type, class_type, size_in_bits, align_in_bits, flags)
  end

  # Creates an Objective-C instance variable debug-info node.
  def create_objc_ivar(name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, type, property_node = nil)
    LibLLVMM.di_builder_create_objc_ivar(self, name, name.bytesize, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, type, property_node)
  end

  # Creates an Objective-C property debug-info node.
  def create_objc_property(name, file, line, getter_name, setter_name, property_attributes, type)
    LibLLVMM.di_builder_create_objc_property(self, name, name.bytesize, file, line,
      getter_name, getter_name.bytesize, setter_name, setter_name.bytesize, property_attributes, type)
  end

  # Creates the type of the implicit object pointer (`self`).
  #
  # The *implicit* flag is only passed through on LLVM 20 and later; it is
  # ignored on earlier versions.
  def create_object_pointer_type(type, implicit = false)
    {% if LibLLVMM::IS_LT_200 %}
      LibLLVMM.di_builder_create_object_pointer_type(self, type)
    {% else %}
      LibLLVMM.di_builder_create_object_pointer_type(self, type, implicit ? 1 : 0)
    {% end %}
  end

  # Creates a qualified (e.g. `const`) type with DWARF *tag* wrapping
  # *type*.
  def create_qualified_type(tag, type)
    LibLLVMM.di_builder_create_qualified_type(self, tag, type)
  end

  # Creates a reference type with DWARF *tag* referring to *type*.
  def create_reference_type(tag, type)
    LibLLVMM.di_builder_create_reference_type(self, tag, type)
  end

  # Creates the type of `nullptr` (`std::nullptr_t`).
  def create_nullptr_type
    LibLLVMM.di_builder_create_nullptr_type(self)
  end

  # Creates a typedef *name* for *type*.
  def create_typedef(type, name, file, line, scope, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_typedef(self, type, name, name.bytesize, file, line, scope, align_in_bits)
  end

  # Creates an inheritance node: *ty* derives from *base_ty* at
  # *base_offset* bits.
  def create_inheritance(ty, base_ty, base_offset, vb_ptr_offset = 0_u32, flags = DIFlags::Zero)
    LibLLVMM.di_builder_create_inheritance(self, ty, base_ty, base_offset, vb_ptr_offset, flags)
  end

  # Creates a forward declaration with DWARF *tag*.
  def create_forward_decl(tag, name, scope, file, line, runtime_lang = 0, size_in_bits = 0_u64, align_in_bits = 0_u32, unique_id = "")
    LibLLVMM.di_builder_create_forward_decl(self, tag, name, name.bytesize, scope, file, line,
      runtime_lang, size_in_bits, align_in_bits, unique_id, unique_id.bytesize)
  end

  # Creates a bitfield member type.
  def create_bitfield_member_type(scope, name, file, line, size_in_bits, offset_in_bits, storage_offset_in_bits, flags, type)
    LibLLVMM.di_builder_create_bitfield_member_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, offset_in_bits, storage_offset_in_bits, flags, type)
  end

  # Creates a class type from *element_types* (created with
  # `#create_member_type`).
  def create_class_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, derived_from,
                        element_types, vtable_holder = nil, template_params = nil, unique_id = "")
    LibLLVMM.di_builder_create_class_type(self, scope, name, name.bytesize, file, line, size_in_bits,
      align_in_bits, offset_in_bits, flags, derived_from, element_types, element_types.size,
      vtable_holder, template_params, unique_id, unique_id.bytesize)
  end

  # Creates a type marked as compiler-generated (artificial).
  def create_artificial_type(type)
    LibLLVMM.di_builder_create_artificial_type(self, type)
  end

  # Creates a constant-valued `DIExpression` holding *value*.
  def create_constant_value_expression(value : UInt64)
    LibLLVMM.di_builder_create_constant_value_expression(self, value)
  end

  # Creates a temporary forward declaration of a global variable, to be
  # replaced later with `#replace_temporary`.
  def create_temp_global_variable_fwd_decl(scope, name, linkage_name, file, line, type, local_to_unit, decl = nil, align_in_bits = 0_u32)
    LibLLVMM.di_builder_create_temp_global_variable_fwd_decl(self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line, type, local_to_unit ? 1 : 0, decl, align_in_bits)
  end

  # Finalizes the debug info (`LLVMDIBuilderFinalize`). Call once, after
  # all metadata has been created and before the module is verified or
  # emitted.
  def end
    LibLLVMM.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
