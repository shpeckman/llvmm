# src/llvmm/builder.cr
class LLVMM::Builder
  @disposed = false

  def initialize(@unwrap : LibLLVMM::BuilderRef)
  end

  def position_at_end(block)
    LibLLVMM.position_builder_at_end(self, block)
  end

  def position_at_begin(block)
    instr = LibLLVMM.get_first_instruction(block)
    if instr
      LibLLVMM.position_builder(self, block, instr)
    else
      position_at_end(block)
    end
  end

  def insert_block
    BasicBlock.new LibLLVMM.get_insert_block(self)
  end

  def insert(instr)
    LibLLVMM.insert_into_builder(self, instr)
  end

  def set_inst_debug_location(instr)
    LibLLVMM.set_inst_debug_location(self, instr)
  end

  def insert(instr, name)
    LibLLVMM.insert_into_builder_with_name(self, instr, name)
  end

  def ret
    Value.new LibLLVMM.build_ret_void(self)
  end

  def ret(value)
    # check_value(value)

    Value.new LibLLVMM.build_ret(self, value)
  end

  def aggregate_ret(values : Array(LLVMM::Value))
    Value.new LibLLVMM.build_aggregate_ret(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  def br(block)
    Value.new LibLLVMM.build_br(self, block)
  end

  def cond(cond, then_block, else_block)
    # check_value(cond)

    Value.new LibLLVMM.build_cond(self, cond, then_block, else_block)
  end

  def phi(type, table : LLVMM::PhiTable, name = "")
    # check_type("phi", type)

    phi type, table.blocks, table.values, name
  end

  def phi(type, incoming_blocks : Array(LLVMM::BasicBlock), incoming_values : Array(LLVMM::Value), name = "")
    # check_type("phi", type)

    phi_node = LibLLVMM.build_phi self, type, name
    LibLLVMM.add_incoming phi_node,
      (incoming_values.to_unsafe.as(LibLLVMM::ValueRef*)),
      (incoming_blocks.to_unsafe.as(LibLLVMM::BasicBlockRef*)),
      incoming_blocks.size
    Value.new phi_node
  end

  def call(type : LLVMM::Type, func : LLVMM::Function, name : String = "")
    # check_type("call", type)
    # check_func(func)

    Value.new LibLLVMM.build_call2(self, type, func, nil, 0, name)
  end

  def call(type : LLVMM::Type, func : LLVMM::Function, arg : LLVMM::Value, name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_value(arg)

    value = arg.to_unsafe
    Value.new LibLLVMM.build_call2(self, type, func, pointerof(value), 1, name)
  end

  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), name : String = "")
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    Value.new LibLLVMM.build_call2(self, type, func, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, name)
  end

  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), name : String, bundle : LLVMM::OperandBundleDef)
    # check_type("call", type)
    # check_func(func)
    # check_values(args)

    bundle_ref  = bundle.to_unsafe
    bundles     = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVMM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new LibLLVMM.build_call_with_operand_bundles(self, type, func, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, bundles, num_bundles, name)
  end

  def call(type : LLVMM::Type, func : LLVMM::Function, args : Array(LLVMM::Value), bundle : LLVMM::OperandBundleDef)
    call(type, func, args, "", bundle)
  end

  def alloca(type, name = "")
    # check_type("alloca", type)

    Value.new LibLLVMM.build_alloca(self, type, name)
  end

  def malloc(type, name = "")
    # check_type("malloc", type)

    Value.new LibLLVMM.build_malloc(self, type, name)
  end

  def free(pointer)
    # check_value(pointer)

    Value.new LibLLVMM.build_free(self, pointer)
  end

  def store(value, ptr)
    # check_value(value, "value")
    # check_value(ptr, "ptr")

    Value.new LibLLVMM.build_store(self, value, ptr)
  end

  def load(type : LLVMM::Type, ptr : LLVMM::Value, name = "")
    # check_type("load", type)
    # check_value(ptr)

    Value.new LibLLVMM.build_load2(self, type, ptr, name)
  end

  def store_volatile(value, ptr)
    store(value, ptr).tap { |v| v.volatile = true }
  end

  def load_volatile(type : LLVMM::Type, ptr : LLVMM::Value, name = "")
    load(type, ptr, name).tap { |v| v.volatile = true }
  end

  {% for method_name in %w(gep inbounds_gep) %}
    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, indices : Array(LLVMM::ValueRef), name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices.to_unsafe.as(LibLLVMM::ValueRef*), indices.size, name)
    end

    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, index : LLVMM::Value, name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      indices = pointerof(index).as(LibLLVMM::ValueRef*)
      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices, 1, name)
    end

    def {{method_name.id}}(type : LLVMM::Type, value : LLVMM::Value, index1 : LLVMM::Value, index2 : LLVMM::Value, name = "")
      # check_type({{method_name}}, type)
      # check_value(value)

      indices = uninitialized LLVMM::Value[2]
      indices[0] = index1
      indices[1] = index2
      Value.new LibLLVMM.build_{{method_name.id}}2(self, type, value, indices.to_unsafe.as(LibLLVMM::ValueRef*), 2, name)
    end
  {% end %}

  def extract_value(value, index, name = "")
    # check_value(value)

    Value.new LibLLVMM.build_extract_value(self, value, index, name)
  end

  def struct_gep(type : LLVMM::Type, value : LLVMM::Value, index : Int, name = "")
    # check_type("struct_gep", type)
    # check_value(value)

    Value.new LibLLVMM.build_struct_gep2(self, type, value, index, name)
  end

  def insert_value(agg_val, elt_val, index : Int, name = "")
    Value.new LibLLVMM.build_insert_value(self, agg_val, elt_val, index, name)
  end

  def extract_element(vec_val, index, name = "")
    Value.new LibLLVMM.build_extract_element(self, vec_val, index, name)
  end

  def insert_element(vec_val, elt_val, index, name = "")
    Value.new LibLLVMM.build_insert_element(self, vec_val, elt_val, index, name)
  end

  def shuffle_vector(v1, v2, mask, name = "")
    Value.new LibLLVMM.build_shuffle_vector(self, v1, v2, mask, name)
  end

  def mem_set(ptr, val, len, align : UInt32 = 0)
    Value.new LibLLVMM.build_mem_set(self, ptr, val, len, align)
  end

  def mem_copy(dst, dst_align : UInt32, src, src_align : UInt32, size)
    Value.new LibLLVMM.build_mem_cpy(self, dst, dst_align, src, src_align, size)
  end

  def mem_move(dst, dst_align : UInt32, src, src_align : UInt32, size)
    Value.new LibLLVMM.build_mem_move(self, dst, dst_align, src, src_align, size)
  end

  def array_alloca(type, count, name = "")
    Value.new LibLLVMM.build_array_alloca(self, type, count, name)
  end

  {% for name in %w(bit_cast zext sext trunc fpext fptrunc fp2si fp2ui si2fp ui2fp int2ptr ptr2int) %}
    def {{name.id}}(value, type, name = "")
      # check_type({{name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  {% for name in %w(fp_cast pointer_cast addr_space_cast sext_or_bit_cast zext_or_bit_cast trunc_or_bit_cast) %}
    def {{name.id}}(value, type, name = "")
      # check_type({{name}}, type)
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, type, name)
    end
  {% end %}

  def int_cast(value, type, is_signed = false, name = "")
    Value.new LibLLVMM.build_int_cast2(self, value, type, is_signed ? 1 : 0, name)
  end

  def cast(op : LLVMM::Opcode, value, type, name = "")
    Value.new LibLLVMM.build_cast(self, op, value, type, name)
  end

  def binop(op : LLVMM::Opcode, lhs, rhs, name = "")
    Value.new LibLLVMM.build_binop(self, op, lhs, rhs, name)
  end

  {% for name in %w(add sub mul) %}
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
    def {{name.id}}(op, lhs, rhs, name = "")
      # check_value(lhs)
      # check_value(rhs)

      Value.new LibLLVMM.build_{{name.id}}(self, op, lhs, rhs, name)
    end
  {% end %}

  {% for name in %w(not neg fneg nsw_neg nuw_neg) %}
    def {{name.id}}(value, name = "")
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, name)
    end
  {% end %}

  def unreachable
    Value.new LibLLVMM.build_unreachable(self)
  end

  def select(cond, a_then, a_else, name = "")
    # check_value(cond)
    # check_value(a_then)
    # check_value(a_else)

    Value.new LibLLVMM.build_select self, cond, a_then, a_else, name
  end

  def global_string(string, name = "")
    Value.new LibLLVMM.build_global_string self, string, name
  end

  def global_string_pointer(string, name = "")
    Value.new LibLLVMM.build_global_string_ptr self, string, name
  end

  {% for name in %w(freeze is_null is_not_null) %}
    def {{name.id}}(value, name = "")
      # check_value(value)

      Value.new LibLLVMM.build_{{name.id}}(self, value, name)
    end
  {% end %}

  def ptr_diff(elem_type : LLVMM::Type, lhs, rhs, name = "")
    Value.new LibLLVMM.build_ptr_diff2(self, elem_type, lhs, rhs, name)
  end

  def landing_pad(type, personality, clauses, name = "")
    # check_type("landing_pad", type)

    lpad = LibLLVMM.build_landing_pad self, type, personality, clauses.size, name
    LibLLVMM.set_cleanup lpad, 1
    clauses.each do |clause|
      LibLLVMM.add_clause lpad, clause
    end
    Value.new lpad
  end

  def catch_switch(parent_pad, basic_block, num_handlers, name = "")
    Value.new LibLLVMM.build_catch_switch(self, parent_pad, basic_block, num_handlers, name)
  end

  def catch_pad(parent_pad, args : Array(LLVMM::Value), name = "")
    Value.new LibLLVMM.build_catch_pad(self, parent_pad, args.to_unsafe.as(LibLLVMM::ValueRef*), args.size, name)
  end

  def cleanup_pad(parent_pad, args : Array(LLVMM::Value), name = "")
    Value.new LibLLVMM.build_cleanup_pad(self, parent_pad, args.to_unsafe.as(LibLLVMM::ValueRef*), args.size, name)
  end

  def cleanup_ret(pad, basic_block)
    Value.new LibLLVMM.build_cleanup_ret(self, pad, basic_block)
  end

  def resume(exn)
    Value.new LibLLVMM.build_resume(self, exn)
  end

  def add_handler(catch_switch_ref, handler)
    LibLLVMM.add_handler catch_switch_ref, handler
  end

  def build_operand_bundle_def(name, values : Array(LLVMM::Value))
    LLVMM::OperandBundleDef.new LibLLVMM.create_operand_bundle(name, name.bytesize, values.to_unsafe.as(LibLLVMM::ValueRef*), values.size)
  end

  def build_catch_ret(pad, basic_block)
    LibLLVMM.build_catch_ret(self, pad, basic_block)
  end

  def invoke(type : LLVMM::Type, fn : LLVMM::Function, args : Array(LLVMM::Value), a_then, a_catch, *, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    Value.new LibLLVMM.build_invoke2 self, type, fn, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, a_then, a_catch, name
  end

  def invoke(type : LLVMM::Type, fn : LLVMM::Function, args : Array(LLVMM::Value), a_then, a_catch, bundle : LLVMM::OperandBundleDef, name = "")
    # check_type("invoke", type)
    # check_func(fn)

    bundle_ref  = bundle.to_unsafe
    bundles     = bundle_ref ? pointerof(bundle_ref) : Pointer(Void).null.as(LibLLVMM::OperandBundleRef*)
    num_bundles = bundle_ref ? 1 : 0
    Value.new LibLLVMM.build_invoke_with_operand_bundles(self, type, fn, (args.to_unsafe.as(LibLLVMM::ValueRef*)), args.size, a_then, a_catch, bundles, num_bundles, name)
  end

  def switch(value, otherwise, cases)
    # check_value(value)

    switch = LibLLVMM.build_switch self, value, otherwise, cases.size
    cases.each do |case_value, block|
      LibLLVMM.add_case switch, case_value, block
    end
    switch
  end

  def indirect_br(addr, num_dests : Int)
    Value.new LibLLVMM.build_indirect_br(self, addr, num_dests)
  end

  def add_destination(indirect_br, block)
    LibLLVMM.add_destination indirect_br, block
  end

  def atomicrmw(op, ptr, val, ordering, singlethread)
    Value.new LibLLVMM.build_atomicrmw(self, op, ptr, val, ordering, singlethread ? 1 : 0)
  end

  def cmpxchg(pointer, cmp, new, success_ordering, failure_ordering, singlethread : Bool = false)
    Value.new LibLLVMM.build_atomic_cmp_xchg(self, pointer, cmp, new, success_ordering, failure_ordering, singlethread ? 1 : 0)
  end

  def fence(ordering, singlethread, name = "")
    Value.new LibLLVMM.build_fence(self, ordering, singlethread ? 1 : 0, name)
  end

  def va_arg(list, type, name = "")
    Value.new LibLLVMM.build_va_arg(self, list, type, name)
  end

  def set_current_debug_location(metadata, context : LLVMM::Context)
    LibLLVMM.set_current_debug_location2(self, metadata)
  end

  def clear_current_debug_location
    LibLLVMM.set_current_debug_location2(self, nil)
  end

  def set_metadata(value, kind, node)
    LibLLVMM.set_metadata(value, kind, node)
  end

  def current_debug_location
    Value.new LibLLVMM.get_current_debug_location(self)
  end

  def default_fp_math_tag : LibLLVMM::MetadataRef
    LibLLVMM.builder_get_default_fp_math_tag(self)
  end

  def default_fp_math_tag=(tag : LibLLVMM::MetadataRef)
    LibLLVMM.builder_set_default_fp_math_tag(self, tag)
  end

  def clear_default_fp_math_tag
    LibLLVMM.builder_set_default_fp_math_tag(self, Pointer(Void).null.as(LibLLVMM::MetadataRef))
  end

  def to_unsafe
    @unwrap
  end

  protected def dispose
    return if @disposed
    @disposed = true

    LibLLVMM.dispose_builder(@unwrap)
  end

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
