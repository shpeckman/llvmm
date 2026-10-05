# src/llvmm/value_methods.cr
module LLVMM::ValueMethods
  def initialize(@unwrap : LibLLVMM::ValueRef)
  end

  def name=(name)
    LibLLVMM.set_value_name2(self, name, name.bytesize)
  end

  def name
    ptr = LibLLVMM.get_value_name2(self, out len)
    String.new(ptr, len)
  end

  def kind
    LibLLVMM.get_value_kind(self)
  end

  def add_instruction_attribute(index : Int, attribute : LLVMM::Attribute, context : LLVMM::Context, type : LLVMM::Type? = nil)
    return if attribute.value == 0

    attribute.each_kind do |kind|
      LibLLVMM.add_call_site_attribute(self, index, attribute_ref(context, kind, type))
    end
  end

  private def attribute_ref(context, kind, type)
    if type.is_a?(Type) && Attribute.requires_type?(kind)
      LibLLVMM.create_type_attribute(context, kind, type)
    else
      LibLLVMM.create_enum_attribute(context, kind, 0)
    end
  end

  def constant?
    LibLLVMM.is_constant(self) != 0
  end

  def type
    Type.new LibLLVMM.type_of(self)
  end

  def thread_local=(thread_local)
    LibLLVMM.set_thread_local(self, thread_local ? 1 : 0)
  end

  def thread_local?
    LibLLVMM.is_thread_local(self) != 0
  end

  def linkage=(linkage)
    LibLLVMM.set_linkage(self, linkage)
  end

  def linkage
    LibLLVMM.get_linkage(self)
  end

  def dll_storage_class=(storage_class)
    LibLLVMM.set_dll_storage_class(self, storage_class)
  end

  def dll_storage_class
    LibLLVMM.get_dll_storage_class(self)
  end

  def section : String
    String.new LibLLVMM.get_section(self)
  end

  def section=(section : String)
    LibLLVMM.set_section(self, section)
  end

  def visibility : LLVMM::Visibility
    LibLLVMM.get_visibility(self)
  end

  def visibility=(visibility : LLVMM::Visibility)
    LibLLVMM.set_visibility(self, visibility)
  end

  def unnamed_address : LLVMM::UnnamedAddress
    LibLLVMM.get_unnamed_address(self)
  end

  def unnamed_address=(unnamed_addr : LLVMM::UnnamedAddress)
    LibLLVMM.set_unnamed_address(self, unnamed_addr)
  end

  def thread_local_mode : LLVMM::ThreadLocalMode
    LibLLVMM.get_thread_local_mode(self)
  end

  def thread_local_mode=(mode : LLVMM::ThreadLocalMode)
    LibLLVMM.set_thread_local_mode(self, mode)
  end

  def externally_initialized? : Bool
    LibLLVMM.is_externally_initialized(self) != 0
  end

  def externally_initialized=(is_ext_init : Bool)
    LibLLVMM.set_externally_initialized(self, is_ext_init ? 1 : 0)
  end

  def delete_global
    LibLLVMM.delete_global(self)
  end

  def next_global : Value?
    global = LibLLVMM.get_next_global(self)
    global.null? ? nil : Value.new(global)
  end

  def previous_global : Value?
    global = LibLLVMM.get_previous_global(self)
    global.null? ? nil : Value.new(global)
  end

  def aliasee : Value
    Value.new LibLLVMM.alias_get_aliasee(self)
  end

  def aliasee=(aliasee : Value)
    LibLLVMM.alias_set_aliasee(self, aliasee)
  end

  def ifunc_resolver : Value
    Value.new LibLLVMM.get_global_ifunc_resolver(self)
  end

  def ifunc_resolver=(resolver)
    LibLLVMM.set_global_ifunc_resolver(self, resolver)
  end

  def erase_ifunc
    LibLLVMM.erase_global_ifunc(self)
  end

  def remove_ifunc
    LibLLVMM.remove_global_ifunc(self)
  end

  def call_convention=(call_convention)
    LibLLVMM.set_instruction_call_convention(self, call_convention)
  end

  def call_convention
    LibLLVMM.get_instruction_call_convention(self)
  end

  def global_constant=(global_constant)
    LibLLVMM.set_global_constant(self, global_constant ? 1 : 0)
  end

  def global_constant?
    LibLLVMM.is_global_constant(self) != 0
  end

  def initializer=(initializer)
    LibLLVMM.set_initializer(self, initializer)
  end

  def initializer
    init = LibLLVMM.get_initializer(self)
    init ? LLVMM::Value.new(init) : nil
  end

  def global_set_metadata(kind : String, metadata)
    kind = LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize)
    global_set_metadata(kind, metadata)
  end

  def global_set_metadata(kind, metadata)
    LibLLVMM.global_set_metadata(self, kind, metadata)
  end

  def clear_metadata
    LibLLVMM.global_clear_metadata(self)
  end

  def erase_metadata(kind : UInt32)
    LibLLVMM.global_erase_metadata(self, kind)
  end

  def erase_metadata(kind : String)
    erase_metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize))
  end

  def each_metadata(& : UInt32, LibLLVMM::MetadataRef ->) : Nil
    entries = LibLLVMM.global_copy_all_metadata(self, out count)
    return if entries.null?
    begin
      count.times do |i|
        yield LibLLVMM.value_metadata_entries_get_kind(entries, i),
          LibLLVMM.value_metadata_entries_get_metadata(entries, i)
      end
    ensure
      LibLLVMM.dispose_value_metadata_entries(entries)
    end
  end

  def copy_all_metadata : Array({UInt32, LibLLVMM::MetadataRef})
    entries = [] of {UInt32, LibLLVMM::MetadataRef}
    each_metadata { |kind, md| entries << {kind, md} }
    entries
  end

  def volatile=(volatile)
    LibLLVMM.set_volatile(self, volatile ? 1 : 0)
  end

  def volatile?
    LibLLVMM.get_volatile(self) != 0
  end

  def ordering=(ordering)
    LibLLVMM.set_ordering(self, ordering)
  end

  def ordering
    LibLLVMM.get_ordering(self)
  end

  def alignment=(bytes)
    LibLLVMM.set_alignment(self, bytes)
  end

  def alignment
    LibLLVMM.get_alignment(self)
  end

  def operand(index)
    Value.new LibLLVMM.get_operand(self, index)
  end

  def set_operand(index, value)
    LibLLVMM.set_operand(self, index, value)
  end

  def operand_use(index)
    LibLLVMM.get_operand_use(self, index)
  end

  def condition
    Value.new LibLLVMM.get_condition(self)
  end

  def condition=(cond)
    LibLLVMM.set_condition(self, cond)
  end

  def conditional?
    LibLLVMM.is_conditional(self) != 0
  end

  def num_successors
    LibLLVMM.get_num_successors(self)
  end

  def successor(i)
    BasicBlock.new LibLLVMM.get_successor(self, i)
  end

  def set_successor(i, block : BasicBlock)
    LibLLVMM.set_successor(self, i, block)
  end

  def nsw
    LibLLVMM.get_nsw(self) != 0
  end

  def nsw=(has_nsw)
    LibLLVMM.set_nsw(self, has_nsw ? 1 : 0)
  end

  def nuw
    LibLLVMM.get_nuw(self) != 0
  end

  def nuw=(has_nuw)
    LibLLVMM.set_nuw(self, has_nuw ? 1 : 0)
  end

  def exact
    LibLLVMM.get_exact(self) != 0
  end

  def exact=(is_exact)
    LibLLVMM.set_exact(self, is_exact ? 1 : 0)
  end

  def in_bounds?
    LibLLVMM.is_in_bounds(self) != 0
  end

  def in_bounds=(in_bounds)
    LibLLVMM.set_is_in_bounds(self, in_bounds ? 1 : 0)
  end

  def called_value
    Value.new LibLLVMM.get_called_value(self)
  end

  def called_function_type
    Type.new LibLLVMM.get_called_function_type(self)
  end

  def tail_call?
    LibLLVMM.is_tail_call(self) != 0
  end

  def tail_call=(is_tail_call)
    LibLLVMM.set_tail_call(self, is_tail_call ? 1 : 0)
  end

  def tail_call_kind
    LibLLVMM.get_tail_call_kind(self)
  end

  def tail_call_kind=(kind)
    LibLLVMM.set_tail_call_kind(self, kind)
  end

  def call_site_attribute_count(index)
    LibLLVMM.get_call_site_attribute_count(self, index)
  end

  def call_site_attributes(index) : Array(LibLLVMM::AttributeRef)
    count = LibLLVMM.get_call_site_attribute_count(self, index)
    ptr   = Pointer(LibLLVMM::AttributeRef).malloc(count)
    LibLLVMM.get_call_site_attributes(self, index, ptr)
    Array.new(count) { |i| ptr[i] }
  end

  def call_site_enum_attribute(index, attribute : Attribute) : LibLLVMM::AttributeRef?
    attribute.each_kind do |kind|
      attr = LibLLVMM.get_call_site_enum_attribute(self, index, kind)
      return attr unless attr.null?
    end
    nil
  end

  def call_site_string_attribute(index, key : String) : LibLLVMM::AttributeRef?
    attr = LibLLVMM.get_call_site_string_attribute(self, index, key, key.bytesize)
    attr unless attr.null?
  end

  def remove_call_site_enum_attribute(index, attribute : Attribute)
    attribute.each_kind do |kind|
      LibLLVMM.remove_call_site_enum_attribute(self, index, kind)
    end
  end

  def remove_call_site_string_attribute(index, key : String)
    LibLLVMM.remove_call_site_string_attribute(self, index, key, key.bytesize)
  end

  def num_operand_bundles
    LibLLVMM.get_num_operand_bundles(self)
  end

  def operand_bundle_at_index(index)
    OperandBundleDef.new LibLLVMM.get_operand_bundle_at_index(self, index)
  end

  def atomicrmw_bin_op
    LibLLVMM.get_atomicrmw_bin_op(self)
  end

  def atomicrmw_bin_op=(bin_op)
    LibLLVMM.set_atomicrmw_bin_op(self, bin_op)
  end

  def cmpxchg_success_ordering
    LibLLVMM.get_cmpxchg_success_ordering(self)
  end

  def cmpxchg_success_ordering=(ordering)
    LibLLVMM.set_cmpxchg_success_ordering(self, ordering)
  end

  def cmpxchg_failure_ordering
    LibLLVMM.get_cmpxchg_failure_ordering(self)
  end

  def cmpxchg_failure_ordering=(ordering)
    LibLLVMM.set_cmpxchg_failure_ordering(self, ordering)
  end

  def atomic_single_thread?
    LibLLVMM.is_atomic_single_thread(self) != 0
  end

  def atomic_single_thread=(single_thread)
    LibLLVMM.set_atomic_single_thread(self, single_thread ? 1 : 0)
  end

  def icmp_predicate
    LibLLVMM.get_icmp_predicate(self)
  end

  def fcmp_predicate
    LibLLVMM.get_fcmp_predicate(self)
  end

  def cast_opcode(dest_ty : Type, src_is_signed : Bool = false, dest_is_signed : Bool = false)
    LibLLVMM.get_cast_opcode(self, src_is_signed ? 1 : 0, dest_ty, dest_is_signed ? 1 : 0)
  end

  def can_use_fast_math_flags?
    LibLLVMM.can_use_fast_math_flags(self) != 0
  end

  def fast_math_flags : FastMathFlags
    FastMathFlags.new LibLLVMM.get_fast_math_flags(self)
  end

  def fast_math_flags=(flags : FastMathFlags)
    LibLLVMM.set_fast_math_flags(self, flags.value)
  end

  def num_handlers
    LibLLVMM.get_num_handlers(self)
  end

  def handlers : Array(BasicBlock)
    count = LibLLVMM.get_num_handlers(self)
    ptr   = Pointer(LibLLVMM::BasicBlockRef).malloc(count)
    LibLLVMM.get_handlers(self, ptr)
    Array.new(count) { |i| BasicBlock.new(ptr[i]) }
  end

  def parent_catch_switch
    Value.new LibLLVMM.get_parent_catch_switch(self)
  end

  def parent_catch_switch=(catch_switch)
    LibLLVMM.set_parent_catch_switch(self, catch_switch)
  end

  def has_personality_fn?
    LibLLVMM.has_personality_fn(self) != 0
  end

  def personality_fn
    Value.new LibLLVMM.get_personality_fn(self)
  end

  def arg_operand(i)
    Value.new LibLLVMM.get_arg_operand(self, i)
  end

  def set_arg_operand(i, value)
    LibLLVMM.set_arg_operand(self, i, value)
  end

  def const_int_get_sext_value
    LibLLVMM.const_int_get_sext_value(self)
  end

  def const_int_get_zext_value
    LibLLVMM.const_int_get_zext_value(self)
  end

  def to_value
    LLVMM::Value.new @unwrap
  end

  def has_metadata? : Bool
    LibLLVMM.has_metadata(self) != 0
  end

  def metadata(kind : UInt32) : Value?
    val = LibLLVMM.get_metadata(self, kind)
    val.null? ? nil : Value.new(val)
  end

  def metadata(kind : String) : Value?
    metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize))
  end

  def set_metadata(kind : UInt32, node)
    LibLLVMM.set_metadata(self, kind, node)
  end

  def set_metadata(kind : String, node)
    set_metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize), node)
  end

  def each_metadata_other_than_debug_loc(& : UInt32, LibLLVMM::MetadataRef ->) : Nil
    entries = LibLLVMM.instruction_get_all_metadata_other_than_debug_loc(self, out count)
    return if entries.null?
    begin
      count.times do |i|
        yield LibLLVMM.value_metadata_entries_get_kind(entries, i),
          LibLLVMM.value_metadata_entries_get_metadata(entries, i)
      end
    ensure
      LibLLVMM.dispose_value_metadata_entries(entries)
    end
  end

  def all_metadata_other_than_debug_loc : Array({UInt32, LibLLVMM::MetadataRef})
    entries = [] of {UInt32, LibLLVMM::MetadataRef}
    each_metadata_other_than_debug_loc { |kind, md| entries << {kind, md} }
    entries
  end

  def debug_loc : Metadata?
    md = LibLLVMM.instruction_get_debug_loc(self)
    md.null? ? nil : Metadata.new(md, type.context)
  end

  def debug_loc=(loc)
    LibLLVMM.instruction_set_debug_loc(self, loc)
  end

  def replace_md_node_operand_with(index : UInt32, replacement)
    LibLLVMM.replace_md_node_operand_with(self, index, replacement)
  end

  def value_as_metadata? : Value?
    val = LibLLVMM.is_a_value_as_metadata(self)
    val.null? ? nil : Value.new(val)
  end

  def subprogram : Metadata?
    md = LibLLVMM.get_subprogram(self)
    md.null? ? nil : Metadata.new(md, type.context)
  end

  def dump
    LibLLVMM.dump_value self
  end

  def inspect(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_value_to_string(self), io)
  end

  def to_unsafe
    @unwrap
  end
end
