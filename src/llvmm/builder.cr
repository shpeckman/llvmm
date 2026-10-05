# src/llvmm/builder.cr
# Builds LLVM IR instructions. Position the builder at a basic block with
# `position_at_end` (or `position_at_begin`), then append instructions with
# the build methods; each returns the created instruction as a `Value`.
#
# Create builders with `Context#new_builder` — the context then disposes them
# when it is finalized. A builder wrapping a raw `LibLLVMM::BuilderRef`
# directly is disposed by its own finalizer.
#
# ```
# func.basic_blocks.append("entry") do |builder|
#   builder.ret builder.add(func.params[0], func.params[1])
# end
# ```
class LLVMM::Builder
  @disposed = false

  # Wraps an existing `LibLLVMM::BuilderRef`.
  def initialize(@unwrap : LibLLVMM::BuilderRef)
  end

  # Positions the builder at the end of *block*; subsequent instructions are
  # appended there.
  def position_at_end(block)
    LibLLVMM.position_builder_at_end(self, block)
  end

  # Positions the builder before the first instruction of *block* (at its end
  # if the block is empty).
  def position_at_begin(block)
    instr = LibLLVMM.get_first_instruction(block)
    if instr
      LibLLVMM.position_builder(self, block, instr)
    else
      position_at_end(block)
    end
  end

  # The basic block the builder is currently inserting into.
  def insert_block
    BasicBlock.new LibLLVMM.get_insert_block(self)
  end

  # Appends an existing instruction at the current position.
  def insert(instr)
    LibLLVMM.insert_into_builder(self, instr)
  end

  # Sets *instr*'s debug location to the builder's current debug location.
  def set_inst_debug_location(instr)
    LibLLVMM.set_inst_debug_location(self, instr)
  end

  # Appends an existing instruction at the current position, giving it
  # *name*.
  def insert(instr, name)
    LibLLVMM.insert_into_builder_with_name(self, instr, name)
  end

  # Builds a `ret void` instruction.
  def ret
    Value.new LibLLVMM.build_ret_void(self)
  end

  # Builds a `ret` instruction returning *value*.
  def ret(value)
    # check_value(value)

    Value.new LibLLVMM.build_ret(self, value)
  end

  # Builds a `ret` instruction returning multiple values as an aggregate.
  def aggregate_ret(values : Array(LLVMM::Value))
    Value.new LibLLVMM.build_aggregate_ret(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  # Builds an unconditional branch to *block*.
  def br(block)
    Value.new LibLLVMM.build_br(self, block)
  end

  # Builds a conditional branch on *cond* to *then_block* or *else_block*.
  def cond(cond, then_block, else_block)
    # check_value(cond)

    Value.new LibLLVMM.build_cond(self, cond, then_block, else_block)
  end

  # Builds a `phi` node of *type* with the incoming blocks/values from a
  # `PhiTable`.
  def phi(type, table : LLVMM::PhiTable, name = "")
    # check_type("phi", type)

    phi type, table.blocks, table.values, name
  end

  # Builds a `phi` node of *type*; *incoming_blocks* and *incoming_values*
  # must be pairwise corresponding.
  def phi(type, incoming_blocks : Array(LLVMM::BasicBlock), incoming_values : Array(LLVMM::Value), name = "")
    # check_type("phi", type)

    phi_node = LibLLVMM.build_phi self, type, name
    LibLLVMM.add_incoming phi_node,
      (incoming_values.to_unsafe.as(LibLLVMM::ValueRef*)),
      (incoming_blocks.to_unsafe.as(LibLLVMM::BasicBlockRef*)),
      incoming_blocks.size
    Value.new phi_node
  end

  # Builds a call to *func* (of function type *type*) with no arguments.
  def call(type : LLVMM::Type, func : LLVMM::Function, name : String = "")
    # check_type("call", type)
    # check_func(func)

    Value.new LibLLVMM.build_call2(self, type, func, nil, 0, name)
  end

  # Builds a call to *func* (of function type *type*) with a single argument.
  def call(type : LLVMM::Type, func : LLVMM::Function, arg : LLVMM::Value, name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_value(arg)

    value = arg.to_unsafe
    Value.new LibLLVMM.build_call2(self, type, func, pointerof(value), 1, name)
  end

  # Builds a call to *func* (of function type *type*) with the given
  # arguments.
  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    Value.new LibLLVMM.build_call2(self, type, func, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, name)
  end

  # Builds a call to *func* with the given arguments and an operand bundle
  # (e.g. a `"deopt"` or `"funclet"` bundle; see `build_operand_bundle_def`).
  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), name : String, bundle : LLVMM::OperandBundleDef)
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    bundle_ref  = bundle.to_unsafe
    bundles     = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVMM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new LibLLVMM.build_call_with_operand_bundles(self, type, func, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, bundles, num_bundles, name)
  end

  # Builds a call to *func* with the given arguments and an operand bundle.
  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), bundle : LLVMM::OperandBundleDef)
    call(type, func, args, "", bundle)
  end

  # Builds a stack allocation (`alloca`) of *type*.
  def alloca(type, name = "")
    # check_type("alloca", type)

    Value.new LibLLVMM.build_alloca(self, type, name)
  end

  # Builds a call to `malloc` allocating *type*.
  def malloc(type, name = "")
    # check_type("malloc", type)

    Value.new LibLLVMM.build_malloc(self, type, name)
  end

  # Builds a call to `free` on *pointer*.
  def free(pointer)
    # check_value(pointer)

    Value.new LibLLVMM.build_free(self, pointer)
  end

  # Builds a `store` of *value* into *ptr*.
  def store(value, ptr)
    # check_value(value, "value")
    # check_value(ptr, "ptr")

    Value.new LibLLVMM.build_store(self, value, ptr)
  end

  # Builds a `load` of *type* from *ptr*.
  def load(type : LLVMM::Type, ptr : LLVMM::Value, name = "")
    # check_type("load", type)
    # check_value(ptr)

    Value.new LibLLVMM.build_load2(self, type, ptr, name)
  end

  # Builds a volatile `store` of *value* into *ptr*.
  def store_volatile(value, ptr)
    store(value, ptr).tap { |v| v.volatile = true }
  end

  # Builds a volatile `load` of *type* from *ptr*.
  def load_volatile(type : LLVMM::Type, ptr : LLVMM::Value, name = "")
    load(type, ptr, name).tap { |v| v.volatile = true }
  end

  {% for method_name in %w(gep inbounds_gep) %}
    # Builds a `getelementptr` address computation with the given indices;
    # the `inbounds_gep` variant additionally asserts the result stays within
    # the allocated object.
    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, indices : Array(LLVMM::ValueRef), name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices.to_unsafe.as(LibLLVMM::ValueRef*), indices.size, name)
    end

    # Builds a `getelementptr` address computation with a single index.
    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, index : LLVMM::Value, name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      indices = pointerof(index).as(LibLLVMM::ValueRef*)
      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices, 1, name)
    end

    # Builds a `getelementptr` address computation with two indices.
    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, index1 : LLVMM::Value, index2 : LLVMM::Value, name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      indices = uninitialized LLVMM::Value[2]
      indices[0] = index1
      indices[1] = index2
      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices.to_unsafe.as(LibLLVMM::ValueRef*), 2, name)
    end
  {% end %}

  # Builds an `extractvalue` of element *index* from aggregate *value*.
  def extract_value(value, index, name = "")
    # check_value(value)

    Value.new LibLLVMM.build_extract_value(self, value, index, name)
  end

  # Builds a `getelementptr` addressing element *index* of the struct *type*
  # pointed to by *value*.
  def struct_gep(type : LLVMM::Type, value : LLVMM::Value, index : Int, name = "")
    # check_type("struct_gep", type)
    # check_value(value)

    Value.new LibLLVMM.build_struct_gep2(self, type, value, index, name)
  end

  # Builds an `insertvalue` placing *elt_val* at *index* of *agg_val*.
  def insert_value(agg_val, elt_val, index : Int, name = "")
    Value.new LibLLVMM.build_insert_value(self, agg_val, elt_val, index, name)
  end

  # Builds an `extractelement` of lane *index* from vector *vec_val*.
  def extract_element(vec_val, index, name = "")
    Value.new LibLLVMM.build_extract_element(self, vec_val, index, name)
  end

  # Builds an `insertelement` placing *elt_val* at lane *index* of *vec_val*.
  def insert_element(vec_val, elt_val, index, name = "")
    Value.new LibLLVMM.build_insert_element(self, vec_val, elt_val, index, name)
  end

  # Builds a `shufflevector` combining *v1* and *v2* according to *mask*.
  def shuffle_vector(v1, v2, mask, name = "")
    Value.new LibLLVMM.build_shuffle_vector(self, v1, v2, mask, name)
  end

  # Builds a `llvm.memset` intrinsic call; *align* of 0 means unaligned.
  def mem_set(ptr, val, len, align : UInt32 = 0)
    Value.new LibLLVMM.build_mem_set(self, ptr, val, len, align)
  end

  # Builds a `llvm.memcpy` intrinsic call with explicit alignments.
  def mem_copy(dst, dst_align : UInt32, src, src_align : UInt32, size)
    Value.new LibLLVMM.build_mem_cpy(self, dst, dst_align, src, src_align, size)
  end

  # Builds a `llvm.memmove` intrinsic call with explicit alignments.
  def mem_move(dst, dst_align : UInt32, src, src_align : UInt32, size)
    Value.new LibLLVMM.build_mem_move(self, dst, dst_align, src, src_align, size)
  end

  # Builds a stack allocation of *count* elements of *type*.
  def array_alloca(type, count, name = "")
    Value.new LibLLVMM.build_array_alloca(self, type, count, name)
  end

  {% for name in %w(bit_cast zext sext trunc fpext fptrunc fp2si fp2ui si2fp ui2fp int2ptr ptr2int) %}
    # Builds the corresponding conversion instruction (e.g. `bit_cast` builds
    # a `bitcast`) of *value* to *type*.
    def {{name.id}}(value, type, name = "")
      # check_type({{name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  {% for name in %w(fp_cast pointer_cast addr_space_cast sext_or_bit_cast zext_or_bit_cast trunc_or_bit_cast) %}
    # Builds the corresponding cast instruction of *value* to *type*.
    def {{name.id}}(value, type, name = "")
      # check_type({{name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  # Builds an integer cast of *value* to *type*; *is_signed* selects sign
  # extension over zero extension when widening.
  def int_cast(value, type, is_signed = false, name = "")
    Value.new LibLLVMM.build_int_cast2(self, value, type, is_signed ? 1 : 0, name)
  end

  # Builds a cast instruction of the given `Opcode`.
  def cast(op : LLVMM::Opcode, value, type, name = "")
    Value.new LibLLVMM.build_cast(self, op, value, type, name)
  end

  # Builds a binary instruction of the given `Opcode`.
  def binop(op : LLVMM::Opcode, lhs, rhs, name = "")
    Value.new LibLLVMM.build_binop(self, op, lhs, rhs, name)
  end

  {% for name in %w(add sub mul) %}
    # Builds an `add`/`sub`/`mul`, dispatching to the floating-point variant
    # when both operands share a float kind. Raises if the operands are not
    # integer/vector values or matching floats.
    def {{name.id}}(lhs, rhs, name = "")
      lhs_kind = lhs.type.kind
      rhs_kind = rhs.type.kind
      if float_kind?(lhs_kind) && lhs_kind == rhs_kind
        return Value.new LibLLVMM.build_f{{name.id}}(self, lhs, rhs, name)
      end
      unless (lhs_kind == LLVMM::Type::Kind::Integer || lhs_kind == LLVMM::Type::Kind::Vector) &&
             (rhs_kind == LLVMM::Type::Kind::Integer || rhs_kind == LLVMM::Type::Kind::Vector)
        raise "invalid operand types for '{{name.id}}': #{lhs.type.inspect} and #{rhs.type.inspect}"
      end
      Value.new LibLLVMM.build_{{name.id}}(self, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(sdiv exact_sdiv udiv exact_udiv srem urem frem shl ashr lshr or and xor fadd fsub fmul fdiv nsw_add nuw_add nsw_sub nuw_sub nsw_mul nuw_mul) %}
    # Builds the corresponding binary operator instruction (the LLVM
    # instruction of the same name).
    def {{name.id}}(lhs, rhs, name = "")
      # check_value(lhs)
      # check_value(rhs)

      Value.new LibLLVMM.build_{{name.id}}(self, lhs, rhs, name)
    end
  {% end %}

  private def float_kind?(kind : LLVMM::Type::Kind) : Bool
    case kind
    when .half?, .float?, .double?, .x86_fp80?, .fp128?, .ppc_fp128?, .b_float?
      true
    else
      false
    end
  end

  {% for name in %w(icmp fcmp) %}
    # Builds a comparison instruction with predicate *op*
    # (`LibLLVMM::IntPredicate` for `icmp`, `LibLLVMM::RealPredicate` for
    # `fcmp`).
    def {{name.id}}(op, lhs, rhs, name = "")
      # check_value(lhs)
      # check_value(rhs)

      Value.new LibLLVMM.build_{{name.id}}(self, op, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(not neg fneg nsw_neg nuw_neg) %}
    # Builds the corresponding unary instruction.
    def {{name.id}}(value, name = "")
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, name)
    end
  {% end %}

  # Builds an `unreachable` terminator.
  def unreachable
    Value.new LibLLVMM.build_unreachable(self)
  end

  # Builds a `select` of *a_then* or *a_else* on *cond*.
  def select(cond, a_then, a_else, name = "")
    # check_value(cond)
    # check_value(a_then)
    # check_value(a_else)

    Value.new LibLLVMM.build_select self, cond, a_then, a_else, name
  end

  # Creates a global constant for *string* and returns the global variable.
  def global_string(string, name = "")
    Value.new LibLLVMM.build_global_string self, string, name
  end

  # Creates a global constant for *string* and returns a pointer to its first
  # character.
  def global_string_pointer(string, name = "")
    Value.new LibLLVMM.build_global_string_ptr self, string, name
  end

  {% for name in %w(freeze is_null is_not_null) %}
    # Builds the corresponding unary instruction on *value*.
    def {{name.id}}(value, name = "")
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, name)
    end
  {% end %}

  # Builds the difference of pointers *lhs* and *rhs* in units of
  # *elem_type*.
  def ptr_diff(elem_type : LLVMM::Type, lhs, rhs, name = "")
    Value.new LibLLVMM.build_ptr_diff2(self, elem_type, lhs, rhs, name)
  end

  # Builds a `landingpad` of *type* with *personality* function, marked as a
  # cleanup, with the given catch clauses (Itanium EH).
  def landing_pad(type, personality, clauses, name = "")
    # check_type("landing_pad", type)

    lpad = LibLLVMM.build_landing_pad self, type, personality, clauses.size, name
    LibLLVMM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVMM.add_clause lpad, clause
    end
    Value.new lpad
  end

  # Builds a `catchswitch` (Windows EH); *num_handlers* reserves handler
  # slots to fill with `add_handler`.
  def catch_switch(parent_pad, basic_block, num_handlers, name = "")
    Value.new LibLLVMM.build_catch_switch(self, parent_pad, basic_block, num_handlers, name)
  end

  # Builds a `catchpad` (Windows EH).
  def catch_pad(parent_pad, args : Array(LLVMM::Value), name = "")
    Value.new LibLLVMM.build_catch_pad(self, parent_pad, args.to_unsafe.as(LibLLVMM::ValueRef*), args.size, name)
  end

  # Builds a `cleanuppad` (Windows EH).
  def cleanup_pad(parent_pad, args : Array(LLVMM::Value), name = "")
    Value.new LibLLVMM.build_cleanup_pad(self, parent_pad, args.to_unsafe.as(LibLLVMM::ValueRef*), args.size, name)
  end

  # Builds a `cleanupret` transferring control to *basic_block* (Windows EH).
  def cleanup_ret(pad, basic_block)
    Value.new LibLLVMM.build_cleanup_ret(self, pad, basic_block)
  end

  # Builds a `resume` of the exception *exn*.
  def resume(exn)
    Value.new LibLLVMM.build_resume(self, exn)
  end

  # Adds a handler block to a `catchswitch` instruction.
  def add_handler(catch_switch_ref, handler)
    LibLLVMM.add_handler catch_switch_ref, handler
  end

  # Creates an `OperandBundleDef` (e.g. a `"deopt"` or `"funclet"` bundle)
  # for use with `call` and `invoke`.
  def build_operand_bundle_def(name, values : Array(LLVMM::Value))
    LLVMM::OperandBundleDef.new LibLLVMM.create_operand_bundle(name, name.bytesize, values.to_unsafe.as(LibLLVMM::ValueRef*), values.size)
  end

  # Builds a `catchret` transferring control to *basic_block* (Windows EH).
  def build_catch_ret(pad, basic_block)
    LibLLVMM.build_catch_ret(self, pad, basic_block)
  end

  # Builds an `invoke` of *fn*: the normal edge continues at *a_then*, the
  # unwind edge at *a_catch*.
  def invoke(type : LLVMM::Type, fn : LLVMM::Function, args : Array(LLVMM::Value), a_then, a_catch, *, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    Value.new LibLLVMM.build_invoke2 self, type, fn, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, a_then, a_catch, name
  end

  # Builds an `invoke` of *fn* with an operand bundle.
  def invoke(type : LLVMM::Type, fn : LLVMM::Function, args : Array(LLVMM::Value), a_then, a_catch, bundle : LLVMM::OperandBundleDef, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    bundle_ref  = bundle.to_unsafe
    bundles     = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVMM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new LibLLVMM.build_invoke_with_operand_bundles(self, type, fn, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, a_then, a_catch, bundles, num_bundles, name)
  end

  # Builds a `switch` on *value* with *otherwise* as the default target;
  # *cases* is an enumerable of `{value, block}` pairs.
  def switch(value, otherwise, cases)
    # check_value(value)

    switch = LibLLVMM.build_switch self, value, otherwise, cases.size
    cases.each do |case_value, block|
      LibLLVMM.add_case switch, case_value, block
    end
    switch
  end

  # Builds an `indirectbr` to *addr* with *num_dests* possible destinations
  # (added with `add_destination`).
  def indirect_br(addr, num_dests : Int)
    Value.new LibLLVMM.build_indirect_br(self, addr, num_dests)
  end

  # Adds a destination block to an `indirectbr` instruction.
  def add_destination(indirect_br, block)
    LibLLVMM.add_destination indirect_br, block
  end

  # Builds an `atomicrmw` of *op* on *ptr* with the given ordering;
  # *singlethread* restricts the operation to a single thread.
  def atomicrmw(op, ptr, val, ordering, singlethread)
    Value.new LibLLVMM.build_atomicrmw(self, op, ptr, val, ordering, singlethread ? 1 : 0)
  end

  # Builds a `cmpxchg` on *pointer* with the given success/failure orderings.
  def cmpxchg(pointer, cmp, new, success_ordering, failure_ordering, singlethread : Bool = false)
    Value.new LibLLVMM.build_atomic_cmp_xchg(self, pointer, cmp, new, success_ordering, failure_ordering, singlethread ? 1 : 0)
  end

  # Builds a `fence` with the given ordering; *singlethread* restricts it to
  # a single thread.
  def fence(ordering, singlethread, name = "")
    Value.new LibLLVMM.build_fence(self, ordering, singlethread ? 1 : 0, name)
  end

  # Builds a `va_arg` of *type* from the va_list *list*.
  def va_arg(list, type, name = "")
    Value.new LibLLVMM.build_va_arg(self, list, type, name)
  end

  # Sets the builder's current debug location, applied to subsequently built
  # instructions.
  def set_current_debug_location(metadata, context : LLVMM::Context)
    LibLLVMM.set_current_debug_location2(self, metadata)
  end

  # Clears the builder's current debug location.
  def clear_current_debug_location
    LibLLVMM.set_current_debug_location2(self, nil)
  end

  # Attaches metadata *node* of kind *kind* to the instruction *value*.
  def set_metadata(value, kind, node)
    LibLLVMM.set_metadata(value, kind, node)
  end

  # The builder's current debug location, as a metadata `Value`.
  def current_debug_location
    Value.new LibLLVMM.get_current_debug_location(self)
  end

  # The metadata tag applied as `!fpmath` to subsequently built
  # floating-point instructions.
  def default_fp_math_tag : LibLLVMM::MetadataRef
    LibLLVMM.builder_get_default_fp_math_tag(self)
  end

  # Sets the metadata tag applied as `!fpmath` to subsequently built
  # floating-point instructions.
  def default_fp_math_tag=(tag : LibLLVMM::MetadataRef)
    LibLLVMM.builder_set_default_fp_math_tag(self, tag)
  end

  # Clears the default `!fpmath` tag.
  def clear_default_fp_math_tag
    LibLLVMM.builder_set_default_fp_math_tag(self, Pointer(Void).null.as(LibLLVMM::MetadataRef))
  end

  # The underlying `LibLLVMM::BuilderRef`.
  def to_unsafe
    @unwrap
  end

  protected def dispose
    return if @disposed
    @disposed = true

    LibLLVMM.dispose_builder(@unwrap)
  end

  # Disposes the builder.
  def finalize
    dispose
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_type(name, type)
  #   if @context != type.context
  #     Context.wrong(@context, type.context, "wrong context for #{name}")
  #   end
  # end

  # private def check_func(func)
  #   # An instruction such as a bitcast to a function type can be passed
  #   # to build, and in that case there's no need to check for context equality
  #   return unless func.kind.function?

  #   context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(func))
  #   if @context.@unwrap != context
  #     Context.wrong(@context, LLVMM::Context.new(context, dispose_on_finalize: false), "wrong context for #{func}")
  #   end
  # end

  # private def check_value(value, msg = nil)
  #   type = value.type
  #   ctx = type.context
  #   if @context != ctx
  #     Context.wrong(@context, ctx, "wrong context for value #{value} #{msg ? "(#{msg})" : ""}")
  #   end
  # end

  # private def check_values(values)
  #   values.each do |value|
  #     check_value(value)
  #   end
  # end
end
