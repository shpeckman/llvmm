# src/llvmm/value_methods.cr

# Shared API of `Value` and `Function`.
#
# The methods fall into groups applying to any LLVM value (naming, kind,
# metadata), to global values (linkage, visibility, section, initializer),
# and to instructions (operands, opcode flags, call-site attributes).
# Calling a group on a value of the wrong kind is undefined at the LLVM
# level; the wrappers do not check.
module LLVMM::ValueMethods
  # Wraps an existing `LibLLVMM::ValueRef` without taking ownership.
  def initialize(@unwrap : LibLLVMM::ValueRef)
  end

  # Sets this value's name, used as its identifier in the IR.
  def name=(name)
    LibLLVMM.set_value_name2(self, name, name.bytesize)
  end

  # This value's name, or an empty string if it is unnamed.
  def name
    ptr = LibLLVMM.get_value_name2(self, out len)
    String.new(ptr, len)
  end

  # This value's `LLVMM::Value::Kind`.
  def kind
    LibLLVMM.get_value_kind(self)
  end

  # Adds *attribute* at call site *index* of this call/invoke instruction.
  #
  # *index* follows `AttributeIndex` conventions: 0 for the return value,
  # `AttributeIndex::FunctionIndex` for the function itself, and 1..N for
  # parameters. Attributes whose kind requires a type (see
  # `Attribute.requires_type?`) are created from *type*.
  #
  # Does nothing when *attribute* is an empty flag set.
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

  # Whether this value is a constant.
  def constant?
    LibLLVMM.is_constant(self) != 0
  end

  # This value's type.
  def type
    Type.new LibLLVMM.type_of(self)
  end

  # Marks this global variable as thread-local.
  def thread_local=(thread_local)
    LibLLVMM.set_thread_local(self, thread_local ? 1 : 0)
  end

  # Whether this global variable is thread-local.
  def thread_local?
    LibLLVMM.is_thread_local(self) != 0
  end

  # Sets this global value's `Linkage`.
  def linkage=(linkage)
    LibLLVMM.set_linkage(self, linkage)
  end

  # This global value's `Linkage`.
  def linkage
    LibLLVMM.get_linkage(self)
  end

  # Sets this global value's `DLLStorageClass`.
  def dll_storage_class=(storage_class)
    LibLLVMM.set_dll_storage_class(self, storage_class)
  end

  # This global value's `DLLStorageClass`.
  def dll_storage_class
    LibLLVMM.get_dll_storage_class(self)
  end

  # The object-file section this global value is emitted into.
  def section : String
    String.new LibLLVMM.get_section(self)
  end

  # Sets the object-file section this global value is emitted into.
  def section=(section : String)
    LibLLVMM.set_section(self, section)
  end

  # This global value's symbol `Visibility`.
  def visibility : LLVMM::Visibility
    LibLLVMM.get_visibility(self)
  end

  # Sets this global value's symbol `Visibility`.
  def visibility=(visibility : LLVMM::Visibility)
    LibLLVMM.set_visibility(self, visibility)
  end

  # This global value's `UnnamedAddress` attribute.
  def unnamed_address : LLVMM::UnnamedAddress
    LibLLVMM.get_unnamed_address(self)
  end

  # Sets this global value's `UnnamedAddress` attribute.
  def unnamed_address=(unnamed_addr : LLVMM::UnnamedAddress)
    LibLLVMM.set_unnamed_address(self, unnamed_addr)
  end

  # This thread-local global's `ThreadLocalMode` (TLS model).
  def thread_local_mode : LLVMM::ThreadLocalMode
    LibLLVMM.get_thread_local_mode(self)
  end

  # Sets this thread-local global's `ThreadLocalMode` (TLS model).
  def thread_local_mode=(mode : LLVMM::ThreadLocalMode)
    LibLLVMM.set_thread_local_mode(self, mode)
  end

  # Whether this global variable is externally initialized.
  def externally_initialized? : Bool
    LibLLVMM.is_externally_initialized(self) != 0
  end

  # Sets whether this global variable is externally initialized.
  def externally_initialized=(is_ext_init : Bool)
    LibLLVMM.set_externally_initialized(self, is_ext_init ? 1 : 0)
  end

  # Deletes this global variable from its module.
  #
  # The value is invalidated; any further use is undefined behavior.
  def delete_global
    LibLLVMM.delete_global(self)
  end

  # The next global variable in the module, or `nil` if this is the last.
  def next_global : Value?
    global = LibLLVMM.get_next_global(self)
    global.null? ? nil : Value.new(global)
  end

  # The previous global variable in the module, or `nil` if this is the
  # first.
  def previous_global : Value?
    global = LibLLVMM.get_previous_global(self)
    global.null? ? nil : Value.new(global)
  end

  # The value this global alias points to.
  def aliasee : Value
    Value.new LibLLVMM.alias_get_aliasee(self)
  end

  # Sets the value this global alias points to.
  def aliasee=(aliasee : Value)
    LibLLVMM.alias_set_aliasee(self, aliasee)
  end

  # The resolver function of this `GlobalIFunc`.
  def ifunc_resolver : Value
    Value.new LibLLVMM.get_global_ifunc_resolver(self)
  end

  # Sets the resolver function of this `GlobalIFunc`.
  def ifunc_resolver=(resolver)
    LibLLVMM.set_global_ifunc_resolver(self, resolver)
  end

  # Removes this ifunc from its module and destroys it.
  #
  # The value is invalidated; any further use is undefined behavior. See
  # `remove_ifunc` for a non-destructive alternative.
  def erase_ifunc
    LibLLVMM.erase_global_ifunc(self)
  end

  # Detaches this ifunc from its module without destroying it. See
  # `erase_ifunc`.
  def remove_ifunc
    LibLLVMM.remove_global_ifunc(self)
  end

  # Sets the `CallConvention` of this call/invoke instruction.
  def call_convention=(call_convention)
    LibLLVMM.set_instruction_call_convention(self, call_convention)
  end

  # The `CallConvention` of this call/invoke instruction.
  def call_convention
    LibLLVMM.get_instruction_call_convention(self)
  end

  # Marks this global variable as constant.
  def global_constant=(global_constant)
    LibLLVMM.set_global_constant(self, global_constant ? 1 : 0)
  end

  # Whether this global variable is constant.
  def global_constant?
    LibLLVMM.is_global_constant(self) != 0
  end

  # Sets this global variable's initializer.
  def initializer=(initializer)
    LibLLVMM.set_initializer(self, initializer)
  end

  # This global variable's initializer, or `nil` if it has none.
  def initializer
    init = LibLLVMM.get_initializer(self)
    init ? LLVMM::Value.new(init) : nil
  end

  # Attaches *metadata* to this global under the metadata kind named *kind*
  # (resolved in this value's context).
  def global_set_metadata(kind : String, metadata)
    kind = LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize)
    global_set_metadata(kind, metadata)
  end

  # Attaches *metadata* to this global under the metadata kind id *kind*.
  def global_set_metadata(kind, metadata)
    LibLLVMM.global_set_metadata(self, kind, metadata)
  end

  # Removes all metadata attached to this global.
  def clear_metadata
    LibLLVMM.global_clear_metadata(self)
  end

  # Removes the metadata of kind id *kind* attached to this global.
  def erase_metadata(kind : UInt32)
    LibLLVMM.global_erase_metadata(self, kind)
  end

  # Removes the metadata of the kind named *kind* attached to this global.
  def erase_metadata(kind : String)
    erase_metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize))
  end

  # Yields each metadata kind id and node attached to this global.
  #
  # The yielded `LibLLVMM::MetadataRef`s are borrowed from the module; the
  # internal entries array is disposed when the block returns.
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

  # All metadata attached to this global, as `{kind_id, MetadataRef}` pairs.
  def copy_all_metadata : Array({UInt32, LibLLVMM::MetadataRef})
    entries = [] of {UInt32, LibLLVMM::MetadataRef}
    each_metadata { |kind, md| entries << {kind, md} }
    entries
  end

  # Marks this load/store instruction as volatile.
  def volatile=(volatile)
    LibLLVMM.set_volatile(self, volatile ? 1 : 0)
  end

  # Whether this load/store instruction is volatile.
  def volatile?
    LibLLVMM.get_volatile(self) != 0
  end

  # Sets the `AtomicOrdering` of this load/store instruction.
  def ordering=(ordering)
    LibLLVMM.set_ordering(self, ordering)
  end

  # The `AtomicOrdering` of this load/store instruction.
  def ordering
    LibLLVMM.get_ordering(self)
  end

  # Sets the alignment, in bytes, of this load/store/alloca instruction.
  def alignment=(bytes)
    LibLLVMM.set_alignment(self, bytes)
  end

  # The alignment, in bytes, of this load/store/alloca instruction.
  def alignment
    LibLLVMM.get_alignment(self)
  end

  # The operand at *index* of this instruction or constant expression.
  def operand(index)
    Value.new LibLLVMM.get_operand(self, index)
  end

  # Replaces the operand at *index* with *value*.
  def set_operand(index, value)
    LibLLVMM.set_operand(self, index, value)
  end

  # The use handle (`LibLLVMM::UseRef`) for the operand at *index*.
  def operand_use(index)
    LibLLVMM.get_operand_use(self, index)
  end

  # The condition of this conditional branch instruction.
  def condition
    Value.new LibLLVMM.get_condition(self)
  end

  # Sets the condition of this conditional branch instruction.
  def condition=(cond)
    LibLLVMM.set_condition(self, cond)
  end

  # Whether this branch instruction is conditional.
  def conditional?
    LibLLVMM.is_conditional(self) != 0
  end

  # The number of successor blocks of this terminator instruction.
  def num_successors
    LibLLVMM.get_num_successors(self)
  end

  # The *i*-th successor block of this terminator instruction.
  def successor(i)
    BasicBlock.new LibLLVMM.get_successor(self, i)
  end

  # Replaces the *i*-th successor block of this terminator instruction.
  def set_successor(i, block : BasicBlock)
    LibLLVMM.set_successor(self, i, block)
  end

  # Whether this arithmetic instruction carries the `nsw` (no signed wrap)
  # flag.
  def nsw
    LibLLVMM.get_nsw(self) != 0
  end

  # Sets the `nsw` (no signed wrap) flag on this arithmetic instruction.
  def nsw=(has_nsw)
    LibLLVMM.set_nsw(self, has_nsw ? 1 : 0)
  end

  # Whether this arithmetic instruction carries the `nuw` (no unsigned
  # wrap) flag.
  def nuw
    LibLLVMM.get_nuw(self) != 0
  end

  # Sets the `nuw` (no unsigned wrap) flag on this arithmetic instruction.
  def nuw=(has_nuw)
    LibLLVMM.set_nuw(self, has_nuw ? 1 : 0)
  end

  # Whether this division or shift instruction carries the `exact` flag.
  def exact
    LibLLVMM.get_exact(self) != 0
  end

  # Sets the `exact` flag on this division or shift instruction.
  def exact=(is_exact)
    LibLLVMM.set_exact(self, is_exact ? 1 : 0)
  end

  # Whether this getelementptr is `inbounds`.
  def in_bounds?
    LibLLVMM.is_in_bounds(self) != 0
  end

  # Marks this getelementptr as `inbounds`.
  def in_bounds=(in_bounds)
    LibLLVMM.set_is_in_bounds(self, in_bounds ? 1 : 0)
  end

  # The callee operand of this call/invoke instruction.
  def called_value
    Value.new LibLLVMM.get_called_value(self)
  end

  # The function type of the callee of this call/invoke instruction.
  def called_function_type
    Type.new LibLLVMM.get_called_function_type(self)
  end

  # Whether this call instruction is marked as a tail call.
  def tail_call?
    LibLLVMM.is_tail_call(self) != 0
  end

  # Marks this call instruction as a tail call.
  def tail_call=(is_tail_call)
    LibLLVMM.set_tail_call(self, is_tail_call ? 1 : 0)
  end

  # This call instruction's `TailCallKind`.
  def tail_call_kind
    LibLLVMM.get_tail_call_kind(self)
  end

  # Sets this call instruction's `TailCallKind`.
  def tail_call_kind=(kind)
    LibLLVMM.set_tail_call_kind(self, kind)
  end

  # The number of attributes at call site *index* of this call/invoke (see
  # `add_instruction_attribute` for index semantics).
  def call_site_attribute_count(index)
    LibLLVMM.get_call_site_attribute_count(self, index)
  end

  # The attribute refs (`LibLLVMM::AttributeRef`) at call site *index* of
  # this call/invoke.
  def call_site_attributes(index) : Array(LibLLVMM::AttributeRef)
    count = LibLLVMM.get_call_site_attribute_count(self, index)
    ptr   = Pointer(LibLLVMM::AttributeRef).malloc(count)
    LibLLVMM.get_call_site_attributes(self, index, ptr)
    Array.new(count) { |i| ptr[i] }
  end

  # The enum attribute ref matching *attribute* at call site *index*, or
  # `nil` if none is present.
  def call_site_enum_attribute(index, attribute : Attribute) : LibLLVMM::AttributeRef?
    attribute.each_kind do |kind|
      attr = LibLLVMM.get_call_site_enum_attribute(self, index, kind)
      return attr unless attr.null?
    end
    nil
  end

  # The string attribute ref for *key* at call site *index*, or `nil` if
  # none is present.
  def call_site_string_attribute(index, key : String) : LibLLVMM::AttributeRef?
    attr = LibLLVMM.get_call_site_string_attribute(self, index, key, key.bytesize)
    attr unless attr.null?
  end

  # Removes the enum attribute matching *attribute* at call site *index*.
  def remove_call_site_enum_attribute(index, attribute : Attribute)
    attribute.each_kind do |kind|
      LibLLVMM.remove_call_site_enum_attribute(self, index, kind)
    end
  end

  # Removes the string attribute for *key* at call site *index*.
  def remove_call_site_string_attribute(index, key : String)
    LibLLVMM.remove_call_site_string_attribute(self, index, key, key.bytesize)
  end

  # The number of operand bundles attached to this call/invoke instruction.
  def num_operand_bundles
    LibLLVMM.get_num_operand_bundles(self)
  end

  # The operand bundle at *index* of this call/invoke instruction, as an
  # `OperandBundleDef`.
  def operand_bundle_at_index(index)
    OperandBundleDef.new LibLLVMM.get_operand_bundle_at_index(self, index)
  end

  # The `AtomicRMWBinOp` of this atomicrmw instruction.
  def atomicrmw_bin_op
    LibLLVMM.get_atomicrmw_bin_op(self)
  end

  # Sets the `AtomicRMWBinOp` of this atomicrmw instruction.
  def atomicrmw_bin_op=(bin_op)
    LibLLVMM.set_atomicrmw_bin_op(self, bin_op)
  end

  # The `AtomicOrdering` applied by this cmpxchg instruction when the
  # comparison succeeds.
  def cmpxchg_success_ordering
    LibLLVMM.get_cmpxchg_success_ordering(self)
  end

  # Sets the `AtomicOrdering` applied by this cmpxchg instruction when the
  # comparison succeeds.
  def cmpxchg_success_ordering=(ordering)
    LibLLVMM.set_cmpxchg_success_ordering(self, ordering)
  end

  # The `AtomicOrdering` applied by this cmpxchg instruction when the
  # comparison fails.
  def cmpxchg_failure_ordering
    LibLLVMM.get_cmpxchg_failure_ordering(self)
  end

  # Sets the `AtomicOrdering` applied by this cmpxchg instruction when the
  # comparison fails.
  def cmpxchg_failure_ordering=(ordering)
    LibLLVMM.set_cmpxchg_failure_ordering(self, ordering)
  end

  # Whether this atomic instruction only synchronizes within a single
  # thread.
  def atomic_single_thread?
    LibLLVMM.is_atomic_single_thread(self) != 0
  end

  # Sets whether this atomic instruction only synchronizes within a single
  # thread.
  def atomic_single_thread=(single_thread)
    LibLLVMM.set_atomic_single_thread(self, single_thread ? 1 : 0)
  end

  # The `IntPredicate` of this `icmp` instruction.
  def icmp_predicate
    LibLLVMM.get_icmp_predicate(self)
  end

  # The `RealPredicate` of this `fcmp` instruction.
  def fcmp_predicate
    LibLLVMM.get_fcmp_predicate(self)
  end

  # The `Opcode` that converts this value to *dest_ty*.
  #
  # *src_is_signed* and *dest_is_signed* select between the signed and
  # unsigned conversion variants.
  def cast_opcode(dest_ty : Type, src_is_signed : Bool = false, dest_is_signed : Bool = false)
    LibLLVMM.get_cast_opcode(self, src_is_signed ? 1 : 0, dest_ty, dest_is_signed ? 1 : 0)
  end

  # Whether this instruction can carry fast-math flags.
  def can_use_fast_math_flags?
    LibLLVMM.can_use_fast_math_flags(self) != 0
  end

  # This instruction's `FastMathFlags`.
  def fast_math_flags : FastMathFlags
    FastMathFlags.new LibLLVMM.get_fast_math_flags(self)
  end

  # Sets this instruction's `FastMathFlags`.
  def fast_math_flags=(flags : FastMathFlags)
    LibLLVMM.set_fast_math_flags(self, flags.value)
  end

  # The number of handler blocks of this catchswitch instruction.
  def num_handlers
    LibLLVMM.get_num_handlers(self)
  end

  # The handler blocks of this catchswitch instruction.
  def handlers : Array(BasicBlock)
    count = LibLLVMM.get_num_handlers(self)
    ptr   = Pointer(LibLLVMM::BasicBlockRef).malloc(count)
    LibLLVMM.get_handlers(self, ptr)
    Array.new(count) { |i| BasicBlock.new(ptr[i]) }
  end

  # The parent catchswitch of this catchpad, cleanuppad or catchswitch
  # instruction.
  def parent_catch_switch
    Value.new LibLLVMM.get_parent_catch_switch(self)
  end

  # Sets the parent catchswitch of this catchpad, cleanuppad or catchswitch
  # instruction.
  def parent_catch_switch=(catch_switch)
    LibLLVMM.set_parent_catch_switch(self, catch_switch)
  end

  # Whether this function has a personality function (for landing-pad
  # exception handling).
  def has_personality_fn?
    LibLLVMM.has_personality_fn(self) != 0
  end

  # The personality function of this function (for landing-pad exception
  # handling).
  def personality_fn
    Value.new LibLLVMM.get_personality_fn(self)
  end

  # The *i*-th argument of this call/invoke instruction.
  def arg_operand(i)
    Value.new LibLLVMM.get_arg_operand(self, i)
  end

  # Replaces the *i*-th argument of this call/invoke instruction.
  def set_arg_operand(i, value)
    LibLLVMM.set_arg_operand(self, i, value)
  end

  # The value of this integer constant, sign-extended to 64 bits.
  def const_int_get_sext_value
    LibLLVMM.const_int_get_sext_value(self)
  end

  # The value of this integer constant, zero-extended to 64 bits.
  def const_int_get_zext_value
    LibLLVMM.const_int_get_zext_value(self)
  end

  # This value as a plain `LLVMM::Value`.
  def to_value
    LLVMM::Value.new @unwrap
  end

  # Whether this instruction has any metadata attached.
  def has_metadata? : Bool
    LibLLVMM.has_metadata(self) != 0
  end

  # The metadata of kind id *kind* attached to this instruction, or `nil`
  # if none.
  def metadata(kind : UInt32) : Value?
    val = LibLLVMM.get_metadata(self, kind)
    val.null? ? nil : Value.new(val)
  end

  # The metadata of the kind named *kind* attached to this instruction, or
  # `nil` if none.
  def metadata(kind : String) : Value?
    metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize))
  end

  # Attaches *node* as metadata of kind id *kind* to this instruction.
  def set_metadata(kind : UInt32, node)
    LibLLVMM.set_metadata(self, kind, node)
  end

  # Attaches *node* as metadata of the kind named *kind* to this
  # instruction.
  def set_metadata(kind : String, node)
    set_metadata(LibLLVMM.get_md_kind_id_in_context(type.context, kind, kind.bytesize), node)
  end

  # Yields each metadata kind id and node attached to this instruction,
  # except the debug location.
  #
  # The yielded `LibLLVMM::MetadataRef`s are borrowed from the module; the
  # internal entries array is disposed when the block returns.
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

  # All metadata attached to this instruction except the debug location, as
  # `{kind_id, MetadataRef}` pairs.
  def all_metadata_other_than_debug_loc : Array({UInt32, LibLLVMM::MetadataRef})
    entries = [] of {UInt32, LibLLVMM::MetadataRef}
    each_metadata_other_than_debug_loc { |kind, md| entries << {kind, md} }
    entries
  end

  # The debug location of this instruction, or `nil` if it has none.
  def debug_loc : Metadata?
    md = LibLLVMM.instruction_get_debug_loc(self)
    md.null? ? nil : Metadata.new(md, type.context)
  end

  # Sets the debug location of this instruction.
  def debug_loc=(loc)
    LibLLVMM.instruction_set_debug_loc(self, loc)
  end

  # Replaces the operand at *index* of the metadata node wrapped by this
  # `ValueAsMetadata`.
  def replace_md_node_operand_with(index : UInt32, replacement)
    LibLLVMM.replace_md_node_operand_with(self, index, replacement)
  end

  # This value if it is a `ValueAsMetadata`, otherwise `nil`.
  def value_as_metadata? : Value?
    val = LibLLVMM.is_a_value_as_metadata(self)
    val.null? ? nil : Value.new(val)
  end

  # The `DISubprogram` debug info attached to this function, or `nil` if
  # none.
  def subprogram : Metadata?
    md = LibLLVMM.get_subprogram(self)
    md.null? ? nil : Metadata.new(md, type.context)
  end

  # Dumps this value's IR to stderr. For debugging only.
  def dump
    LibLLVMM.dump_value self
  end

  # Appends this value's LLVM IR representation to *io*.
  def inspect(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_value_to_string(self), io)
  end

  # The underlying `LibLLVMM::ValueRef`, for FFI calls.
  def to_unsafe
    @unwrap
  end
end
