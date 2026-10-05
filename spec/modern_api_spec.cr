# spec/modern_api_spec.cr
require "./spec_helper"

describe "LLVM 19+ C API surface" do
  {% unless LibLLVMM::IS_LT_190 %}
    it "builds GEPs with no-wrap flags and reads them back" do
      context = LLVMM::Context.new
      mod = context.new_module("gep_flags")
      func = mod.functions.add("f", [context.int32], context.int32)
      func.basic_blocks.append("entry") do |builder|
        ptr = builder.alloca(context.int32, "x")
        gep = LibLLVMM.build_gep_with_no_wrap_flags(builder, context.int32, ptr, pointerof(ptr).as(LibLLVMM::ValueRef*), 1, "gep", LLVMM::GEPNoWrapFlags::InBounds | LLVMM::GEPNoWrapFlags::NUSW)
        LibLLVMM.gep_get_no_wrap_flags(gep).should eq(LLVMM::GEPNoWrapFlags::InBounds | LLVMM::GEPNoWrapFlags::NUSW)
        builder.ret func.params[0]
      end
    end

    it "manipulates prefix and prologue data" do
      context = LLVMM::Context.new
      mod = context.new_module("prefix")
      func = mod.functions.add("f", [context.int32], context.int32)
      func.basic_blocks.append("entry") { |builder| builder.ret func.params[0] }

      LibLLVMM.has_prefix_data(func).should eq(0)
      LibLLVMM.set_prefix_data(func, context.int32.const_int(1))
      LibLLVMM.has_prefix_data(func).should_not eq(0)
      LibLLVMM.get_prefix_data(func).should_not be_nil
    end
  {% end %}

  {% unless LibLLVMM::IS_LT_200 %}
    it "exposes value/builder contexts and atomic predicates" do
      context = LLVMM::Context.new
      mod = context.new_module("ctx")
      func = mod.functions.add("f", [context.int32], context.int32)
      func.basic_blocks.append("entry") do |builder|
        LibLLVMM.get_builder_context(builder).should eq(context.to_unsafe)
        LibLLVMM.get_value_context(func).should eq(context.to_unsafe)
        LibLLVMM.is_atomic(func.params[0]).should eq(0)
        builder.ret func.params[0]
      end
    end

    it "applies a custom AA pipeline through PassBuilderOptions" do
      LLVMM.init_native_target

      context = LLVMM::Context.new
      mod = context.new_module("aa_pipeline")
      int32_ty = context.int32
      fn = mod.functions.add("f", [int32_ty], int32_ty)
      fn.basic_blocks.append("entry") do |builder|
        slot = builder.alloca(int32_ty, "slot")
        builder.store(fn.params[0], slot)
        builder.ret(builder.load(int32_ty, slot))
      end
      unoptimized = mod.to_s

      triple = LLVMM.default_target_triple
      machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)

      LLVMM::PassBuilderOptions.new do |options|
        options.set_aa_pipeline("basic-aa")
        LLVMM.run_passes(mod, "default<O2>", machine, options)
      end

      mod.to_s.should_not eq(unoptimized)

      LLVMM::JITCompiler.new(mod) do |jit|
        run = Proc(Int32, Int32).new(jit.function_address("f"), Pointer(Void).null)
        run.call(42).should eq(42)
      end
    end
  {% end %}

  {% unless LibLLVMM::IS_LT_210 %}
    it "round-trips the icmp same-sign flag" do
      context = LLVMM::Context.new
      mod = context.new_module("icmp")
      func = mod.functions.add("f", [context.int1], context.int1)
      func.basic_blocks.append("entry") do |builder|
        cmp = LibLLVMM.build_icmp(builder, LLVMM::IntPredicate::EQ, func.params[0], func.params[0], "cmp")
        LibLLVMM.get_icmp_same_sign(cmp).should eq(0)
        LibLLVMM.set_icmp_same_sign(cmp, 1)
        LibLLVMM.get_icmp_same_sign(cmp).should_not eq(0)
        builder.ret cmp
      end
    end
  {% end %}

  {% unless LibLLVMM::IS_LT_220 %}
    it "gets-or-inserts functions by name" do
      context = LLVMM::Context.new
      mod = context.new_module("get_or_insert")
      ty = LibLLVMM.function_type(context.int32, nil, 0, 0)

      f1 = LibLLVMM.get_or_insert_function(mod, "g", 1, ty)
      f1.should_not be_nil
      f2 = LibLLVMM.get_or_insert_function(mod, "g", 1, ty)
      f2.should eq(f1)
      mod.functions["g"].to_unsafe.should eq(f1)
    end
  {% end %}

  {% unless LibLLVMM::IS_LT_230 %}
    it "supports the byte type and byte constants" do
      context = LLVMM::Context.new
      byte_ty = LibLLVMM.byte_type_in_context(context, 8)
      LibLLVMM.get_byte_type_width(byte_ty).should eq(8)

      c = LibLLVMM.const_byte(byte_ty, 65)
      LibLLVMM.const_byte_get_zext_value(c).should eq(65)
    end
  {% end %}
end

describe "C API surface on every supported version" do
  it "exposes the function value type for typed calls" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    mod     = context.new_module("fn_type")
    add     = mod.functions.add("add", [context.int32, context.int32], context.int32)
    add.basic_blocks.append("entry") do |builder|
      builder.ret(builder.add(add.params[0], add.params[1]))
    end

    fun_ty = add.function_type
    fun_ty.kind.should eq(LLVMM::Type::Kind::Function)
    fun_ty.params_types.size.should eq(2)
    fun_ty.params_types.each { |ty| ty.int_width.should eq(32) }
    fun_ty.return_type.int_width.should eq(32)

    caller = mod.functions.add("caller", [] of LLVMM::Type, context.int32)
    caller.basic_blocks.append("entry") do |builder|
      sum = builder.call(fun_ty, add, [context.int32.const_int(19), context.int32.const_int(23)], "calltmp")
      builder.ret sum
    end
    mod.verify

    LLVMM::JITCompiler.new(mod) do |jit|
      run = Proc(Int32).new(jit.function_address("caller"), Pointer(Void).null)
      run.call.should eq(42)
    end
  end

  it "builds invokes with a landing pad and operand bundles" do
    context  = LLVMM::Context.new
    mod      = context.new_module("eh")
    int32_ty = context.int32

    personality = mod.functions.add("__gxx_personality_v0", [] of LLVMM::Type, int32_ty)
    callee      = mod.functions.add("may_throw", [int32_ty], int32_ty)
    callee.basic_blocks.append("entry") { |builder| builder.ret callee.params[0] }

    func = mod.functions.add("wrapper", [int32_ty], int32_ty)
    func.personality_function = personality

    entry = func.basic_blocks.append("entry")
    ok    = func.basic_blocks.append("ok")
    ok2   = func.basic_blocks.append("ok2")
    lpad  = func.basic_blocks.append("lpad")

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.invoke(callee.function_type, callee, [func.params[0]], ok, lpad, name: "attempt")

    builder.position_at_end(ok)
    bundle = builder.build_operand_bundle_def("deopt", [int32_ty.const_int(1)])
    builder.invoke(callee.function_type, callee, [func.params[0]], ok2, lpad, bundle, name: "attempt2")

    builder.position_at_end(ok2)
    builder.call(callee.function_type, callee, [func.params[0]], "bundled", bundle)
    bundle.dispose
    builder.ret int32_ty.const_int(0)

    builder.position_at_end(lpad)
    lp_ty  = context.struct([context.void_pointer, int32_ty])
    caught = builder.landing_pad(lp_ty, personality, [] of LLVMM::Value, "caught")
    builder.ret(builder.extract_value(caught, 1, "selector"))

    mod.verify
    ir = mod.to_s
    ir.should contain("invoke i32 @may_throw")
    ir.should contain("personality ptr @__gxx_personality_v0")
    ir.should contain("landingpad { ptr, i32 }")
    ir.should contain("\"deopt\"(")
  end

  it "builds a catchswitch funclet with catchpad and catchret" do
    context = LLVMM::Context.new
    mod     = context.new_module("wineh")

    personality = mod.functions.add("__C_specific_handler", [] of LLVMM::Type, context.int32)
    callee      = mod.functions.add("may_throw", [] of LLVMM::Type, context.void)

    func = mod.functions.add("wrapper", [] of LLVMM::Type, context.void)
    func.personality_function = personality

    entry = func.basic_blocks.append("entry")
    cont  = func.basic_blocks.append("cont")
    cs_bb = func.basic_blocks.append("cs_bb")
    cp_bb = func.basic_blocks.append("cp_bb")

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.invoke(callee.function_type, callee, [] of LLVMM::Value, cont, cs_bb)

    builder.position_at_end(cont)
    builder.ret

    builder.position_at_end(cs_bb)
    cs = builder.catch_switch(LLVMM::Value.null, LLVMM::BasicBlock.null, 1, "cs")

    builder.position_at_end(cp_bb)
    cp = builder.catch_pad(cs, [] of LLVMM::Value, "cp")
    builder.build_catch_ret(cp, cont)
    builder.add_handler(cs, cp_bb)

    mod.verify
    ir = mod.to_s
    ir.should contain("catchswitch within none")
    ir.should contain("catchpad within %cs")
    ir.should contain("catchret from %cp")
  end

  it "builds and JITs atomic and volatile operations" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("atomics")
    int32_ty = context.int32

    func = mod.functions.add("atomic_ops", [context.void_pointer, int32_ty], int32_ty)
    func.basic_blocks.append("entry") do |builder|
      old = builder.atomicrmw(LLVMM::AtomicRMWBinOp::Add, func.params[0], func.params[1], LLVMM::AtomicOrdering::SequentiallyConsistent, false)
      builder.cmpxchg(func.params[0], func.params[1], int32_ty.const_int(0), LLVMM::AtomicOrdering::Acquire, LLVMM::AtomicOrdering::Monotonic)
      builder.fence(LLVMM::AtomicOrdering::Release, false)
      builder.store_volatile(func.params[1], func.params[0])
      builder.load_volatile(int32_ty, func.params[0], "v")
      builder.ret(old)
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("atomicrmw add")
    ir.should contain("cmpxchg")
    ir.should contain("fence release")
    ir.should contain("store volatile")
    ir.should contain("load volatile")

    cell = Pointer(Int32).malloc(1)
    cell.value = 10
    LLVMM::JITCompiler.new(mod) do |jit|
      run = Proc(Pointer(Int32), Int32, Int32).new(jit.function_address("atomic_ops"), Pointer(Void).null)
      run.call(cell, 5).should eq(10)
      cell.value.should eq(5)
    end
  end

  it "emits assembly and objects to buffers and files through TargetMachine" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("emit")
    int32_ty = context.int32
    answer   = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    answer.basic_blocks.append("entry") { |builder| builder.ret(int32_ty.const_int(42)) }

    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
    machine.triple.should eq(triple)
    machine.cpu.should eq(LLVMM.host_cpu_name)
    machine.target.name.should_not be_empty

    String.new(machine.emit_asm_to_memory_buffer(mod).to_slice).should contain("answer")

    asm_path = File.tempname("llvmm_emit", ".s")
    obj_path = File.tempname("llvmm_emit", ".o")
    begin
      machine.emit_asm_to_file(mod, asm_path).should be_true
      machine.emit_obj_to_file(mod, obj_path).should be_true
      File.read(asm_path).should contain("answer")
      File.size(obj_path).should be > 0
    ensure
      File.delete(asm_path) if File.exists?(asm_path)
      File.delete(obj_path) if File.exists?(obj_path)
    end
  end

  it "emits objects with global isel enabled" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("gisel")
    int32_ty = context.int32
    answer   = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    answer.basic_blocks.append("entry") { |builder| builder.ret(int32_ty.const_int(42)) }

    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name, "", LLVMM::CodeGenOptLevel::None)
    machine.enable_global_isel = true

    machine.emit_obj_to_memory_buffer(mod).to_slice.size.should be > 0
  end

  it "round-trips bitcode through memory buffers, files, and fds" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("bitcode_rt")
    int32_ty = context.int32
    mod.name.should eq("bitcode_rt")
    mod.name = "bitcode_rt_renamed"
    mod.name.should eq("bitcode_rt_renamed")
    fn = mod.functions.add("add_one", [int32_ty], int32_ty)
    fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.add(fn.params[0], int32_ty.const_int(1)))
    end

    parsed = LLVMM::Module.parse(mod.write_bitcode_to_memory_buffer, context)
    parsed.functions["add_one"].function_type.params_types.size.should eq(1)
    LLVMM::JITCompiler.new(parsed) do |jit|
      run = Proc(Int32, Int32).new(jit.function_address("add_one"), Pointer(Void).null)
      run.call(41).should eq(42)
    end

    bc_path = File.tempname("llvmm_bitcode", ".bc")
    begin
      mod.write_bitcode_to_file(bc_path).should eq(0)
      from_file = LLVMM::Module.parse(LLVMM::MemoryBuffer.from_file(bc_path), context)
      from_file.functions["add_one"].name.should eq("add_one")
    ensure
      File.delete(bc_path) if File.exists?(bc_path)
    end

    fd_path = File.tempname("llvmm_bitcode_fd", ".bc")
    begin
      File.open(fd_path, "w") do |file|
        mod.write_bitcode_to_fd(file.fd).should eq(0)
      end
      from_fd = LLVMM::Module.parse(LLVMM::MemoryBuffer.from_file(fd_path), context)
      from_fd.functions["add_one"].name.should eq("add_one")
    ensure
      File.delete(fd_path) if File.exists?(fd_path)
    end
  end

  it "transfers buffer ownership to LLVM when parsing IR and bitcode" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("ownership")
    int32_ty = context.int32
    fn = mod.functions.add("add_one", [int32_ty], int32_ty)
    fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.add(fn.params[0], int32_ty.const_int(1)))
    end

    ir_buffer = LLVMM::MemoryBuffer.create_copy(mod.to_s.to_slice)
    context.parse_ir(ir_buffer).functions["add_one"].name.should eq("add_one")
    expect_raises(Exception, /Failed to take ownership/) do
      context.parse_ir(ir_buffer)
    end

    bc_buffer = mod.write_bitcode_to_memory_buffer
    LLVMM::Module.parse(bc_buffer, context).functions["add_one"].name.should eq("add_one")
    expect_raises(Exception, /Failed to take ownership/) do
      LLVMM::Module.parse(bc_buffer, context)
    end

    GC.collect
  end

  it "round-trips GenericValue conversions" do
    context = LLVMM::Context.new

    int_gv = LLVMM::GenericValue.new(LibLLVMM.create_generic_value_of_int(context.int64, 42, 1), context)
    int_gv.to_i64.should eq(42_i64)
    int_gv.to_i.should eq(42)
    int_gv.to_u64.should eq(42_u64)
    int_gv.to_b.should be_true

    neg_gv = LLVMM::GenericValue.new(LibLLVMM.create_generic_value_of_int(context.int64, (-7_i64).to_u64!, 1), context)
    neg_gv.to_i64.should eq(-7_i64)

    cell   = Pointer(Int32).malloc(1)
    ptr_gv = LLVMM::GenericValue.new(LibLLVMM.create_generic_value_of_pointer(cell.as(Void*)), context)
    ptr_gv.to_pointer.should eq(cell.as(Void*))

    LLVMM.init_native_target
    mod       = context.new_module("gv_float")
    double_ty = context.double
    fn        = mod.functions.add("answer_f64", [] of LLVMM::Type, double_ty)
    fn.basic_blocks.append("entry") do |builder|
      builder.ret(double_ty.const_double(42.0))
    end
    fn_f32 = mod.functions.add("answer_f32", [] of LLVMM::Type, context.float)
    fn_f32.basic_blocks.append("entry") do |builder|
      builder.ret(context.float.const_float(21.0_f32))
    end
    LLVMM::JITCompiler.new(mod) do |jit|
      ret = jit.run_function(fn, context)
      ret.to_f64.should eq(42.0)
      jit.run_function(fn_f32, context).to_f32.should eq(21.0_f32)
    end
  end

  it "drives the Orc LLJIT layer directly" do
    LLVMM.init_native_target

    ts_ctx = uninitialized LLVMM::Orc::ThreadSafeContext
    context = uninitialized LLVMM::Context
    {% if LibLLVMM::IS_LT_210 %}
      ts_ctx = LLVMM::Orc::ThreadSafeContext.new
      context = ts_ctx.context
    {% else %}
      context = LLVMM::Context.new
      ts_ctx = LLVMM::Orc::ThreadSafeContext.new(context)
    {% end %}
    mod = context.new_module("orc_raw")
    mod.target = LLVMM.default_target_triple

    int32_ty  = context.int32
    abs_fn    = mod.functions.add("abs", [int32_ty], int32_ty)
    caller_fn = mod.functions.add("call_abs", [int32_ty], int32_ty)
    caller_fn.basic_blocks.append("entry") do |builder|
      result = builder.call(abs_fn.function_type, abs_fn, [caller_fn.params[0]], "absval")
      builder.ret result
    end

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    {'_', '\0'}.includes?(lljit.global_prefix).should be_true

    tsm = LLVMM::Orc::ThreadSafeModule.new(mod, ts_ctx)
    lljit.add_llvm_ir_module(lljit.main_jit_dylib, tsm)
    lljit.main_jit_dylib.link_symbols_from_current_process(lljit.global_prefix)

    address = lljit.lookup("call_abs")
    address.should_not eq(Pointer(Void).null)
    run = Proc(Int32, Int32).new(address, Pointer(Void).null)
    run.call(-7).should eq(7)

    lljit.dispose
    ts_ctx.dispose
  end

  it "builds and JITs switch and select" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("switch_select")
    int32_ty = context.int32

    func    = mod.functions.add("classify", [int32_ty], int32_ty)
    entry   = func.basic_blocks.append("entry")
    default = func.basic_blocks.append("default")
    case1   = func.basic_blocks.append("case1")
    case2   = func.basic_blocks.append("case2")

    builder = context.new_builder
    builder.position_at_end(entry)
    sw = builder.switch(func.params[0], default, {
      int32_ty.const_int(1) => case1,
      int32_ty.const_int(2) => case2,
    })
    sw.null?.should be_false
    builder.position_at_end(case1)
    builder.ret int32_ty.const_int(10)
    builder.position_at_end(case2)
    builder.ret int32_ty.const_int(20)
    builder.position_at_end(default)
    builder.ret int32_ty.const_int(0)

    max = mod.functions.add("max", [int32_ty, int32_ty], int32_ty)
    max.basic_blocks.append("entry") do |b|
      cmp = b.icmp(LLVMM::IntPredicate::SGT, max.params[0], max.params[1], "cmp")
      b.ret(b.select(cmp, max.params[0], max.params[1], "max"))
    end

    mod.verify

    LLVMM::JITCompiler.new(mod) do |jit|
      classify = Proc(Int32, Int32).new(jit.function_address("classify"), Pointer(Void).null)
      classify.call(1).should eq(10)
      classify.call(2).should eq(20)
      classify.call(9).should eq(0)

      max_fn = Proc(Int32, Int32, Int32).new(jit.function_address("max"), Pointer(Void).null)
      max_fn.call(19, 23).should eq(23)
      max_fn.call(42, 7).should eq(42)
    end
  end

  it "builds va_arg in varargs functions and calls inline asm" do
    context  = LLVMM::Context.new
    mod      = context.new_module("varargs_asm")
    int32_ty = context.int32

    va_ty = LLVMM::Type.function([context.void_pointer], int32_ty, true)
    va_ty.varargs?.should be_true
    va_fn = mod.functions.add("va_read", va_ty)
    va_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.va_arg(va_fn.params[0], int32_ty, "arg"))
    end

    asm_ty  = LLVMM::Type.function([] of LLVMM::Type, context.void)
    asm_val = asm_ty.inline_asm("nop", "", has_side_effects: true)
    asm_val.kind.should eq(LLVMM::Value::Kind::InlineAsm)
    asm_fn = mod.functions.add("call_asm", [] of LLVMM::Type, context.void)
    asm_fn.basic_blocks.append("entry") do |builder|
      builder.call(asm_ty, LLVMM::Function.from_value(asm_val))
      builder.ret
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("va_arg")
    ir.should contain("asm sideeffect")
  end

  it "manages module globals" do
    context  = LLVMM::Context.new
    mod      = context.new_module("globals")
    int32_ty = context.int32

    counter = mod.globals.add(int32_ty, "counter")
    counter.name.should eq("counter")
    counter.initializer = int32_ty.const_int(7)
    counter.initializer.not_nil!.constant?.should be_true

    mod.globals["counter"].to_unsafe.should eq(counter.to_unsafe)
    mod.globals["missing"]?.should be_nil
    expect_raises(Exception, "Global not found: missing") { mod.globals["missing"] }

    counter.global_constant = true
    counter.global_constant?.should be_true
    counter.thread_local = true
    counter.thread_local?.should be_true

    mod.verify
    ir = mod.to_s
    ir.should contain("@counter = thread_local constant i32 7")
  end

  it "inspects aggregate types and queries target data" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    int32_ty = context.int32
    int8_ty  = context.int8

    point = context.struct("point") { [int32_ty, int32_ty] }
    point.struct_name.should eq("point")
    point.packed_struct?.should be_false
    point.struct_element_types.should eq([int32_ty, int32_ty])

    anonymous = context.struct([int8_ty], packed: true)
    anonymous.struct_name.should be_nil
    anonymous.packed_struct?.should be_true

    arr = int32_ty.array(16)
    arr.element_type.should eq(int32_ty)
    arr.array_size.should eq(16)

    vec = context.double.vector(4)
    vec.element_type.should eq(context.double)
    vec.vector_size.should eq(4)

    expect_raises(Exception, "Not a sequential type") { point.element_type }
    expect_raises(Exception, "Typed pointers are unavailable") { context.void_pointer.element_type }

    triple = LLVMM.default_target_triple
    data   = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name).data_layout
    pair   = context.struct([int8_ty, int32_ty])
    data.offset_of_element(pair, 0).should eq(0)
    data.offset_of_element(pair, 1).should eq(4)
    data.abi_size(pair).should eq(8)
    data.abi_alignment(int32_ty).should eq(4)
    data.size_in_bits(int32_ty).should eq(32)
    data.size_in_bytes(context.double).should eq(8)
    data.to_data_layout_string.should_not be_empty
  end

  it "emits DWARF debug info through DIBuilder" do
    context  = LLVMM::Context.new
    mod      = context.new_module("debug_info")
    int32_ty = context.int32
    mod.add_flag(LibLLVMM::ModuleFlagBehavior::Error, "Debug Info Version", LLVMM::DEBUG_METADATA_VERSION)

    di   = LLVMM::DIBuilder.new(mod)
    file = di.create_file("test.cr", "/src")
    cu   = di.create_compile_unit(LLVMM::DwarfSourceLanguage::Crystal, "test.cr", "/src", "llvmm-spec", false, "", 0)
    cu.null?.should be_false

    int_di   = di.create_basic_type("Int32", 32, 32, LLVMM::DwarfTypeEncoding::Signed)
    sub_ty   = di.create_subroutine_type(file, [int_di])
    type_arr = di.get_or_create_type_array([int_di])
    type_arr.null?.should be_false

    member    = di.create_member_type(cu, "value", file, 7, 32, 32, 0, LLVMM::DIFlags::Zero, int_di)
    struct_di = di.create_struct_type(cu, "Box", file, 6, 32, 32, LLVMM::DIFlags::Zero, nil, [member])
    union_di  = di.create_union_type(cu, "Value", file, 8, 32, 32, LLVMM::DIFlags::Zero, [member])
    union_di.null?.should be_false

    enum_a  = di.create_enumerator("Red", 1)
    enum_b  = di.create_enumerator("Green", 2)
    enum_di = di.create_enumeration_type(cu, "Color", file, 5, 32, 32, [enum_a, enum_b], int_di)
    enum_di.null?.should be_false

    subrange = di.get_or_create_array_subrange(0, 10)
    array_di = di.create_array_type(320, 32, int_di, [subrange])
    array_di.null?.should be_false
    ptr_di = di.create_pointer_type(int_di, 64, 64, "Int32*")
    ptr_di.null?.should be_false
    di.create_unspecified_type("Opaque").null?.should be_false

    tmp = di.create_replaceable_composite_type(cu, "Node", file, 10)
    di.replace_temporary(tmp, struct_di)

    func       = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    entry      = func.basic_blocks.append("entry")
    subprogram = di.create_function(cu, "answer", "answer", file, 1, sub_ty, false, true, 1, LLVMM::DIFlags::Prototyped, false, func)
    subprogram.null?.should be_false

    gv = mod.globals.add(int32_ty, "global_answer")
    gv.initializer = int32_ty.const_int(42)
    gve = di.create_global_variable_expression(cu, "global_answer", "global_answer", file, 2, enum_di, false)
    gve.null?.should be_false
    gv.global_set_metadata("dbg", gve)

    builder = context.new_builder
    builder.position_at_end(entry)
    storage = builder.alloca(int32_ty, "x")
    builder.store(int32_ty.const_int(42), storage)

    loc      = di.create_debug_location(3, 2, subprogram)
    auto_var = di.create_auto_variable(subprogram, "x", file, 3, struct_di, 32)
    auto_var.null?.should be_false
    di.create_parameter_variable(subprogram, "n", 1, file, 1, int_di).null?.should be_false
    di.insert_declare_at_end(storage, auto_var, di.create_expression(nil, 0), loc, entry)

    builder.set_current_debug_location(loc, context)
    builder.ret(builder.load(int32_ty, storage))
    builder.clear_current_debug_location

    di.end
    mod.verify
    ir = mod.to_s
    ir.should contain("!DICompileUnit")
    ir.should contain("!DISubprogram")
    ir.should contain("DILocalVariable")
    ir.should contain("DICompositeType")
    ir.should contain("DIGlobalVariableExpression")
  end

  it "builds flagged integer arithmetic" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("flagged_arith")
    int32_ty = context.int32

    func = mod.functions.add("arith", [int32_ty, int32_ty], int32_ty)
    func.basic_blocks.append("entry") do |builder|
      a = builder.nsw_add(func.params[0], func.params[1])
      b = builder.nuw_sub(a, func.params[1])
      c = builder.nsw_mul(b, func.params[1])
      d = builder.nuw_mul(c, func.params[1])
      e = builder.nsw_neg(d)
      builder.ret(builder.nuw_neg(e))
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("add nsw")
    ir.should contain("sub nuw")
    ir.should contain("mul nsw")
    ir.should contain("mul nuw")

    LLVMM::JITCompiler.new(mod) do |jit|
      arith = Proc(Int32, Int32, Int32).new(jit.function_address("arith"), Pointer(Void).null)
      arith.call(3, 4).should eq(48)
    end
  end

  it "builds exact unsigned division and float remainder" do
    LLVMM.init_native_target

    context   = LLVMM::Context.new
    mod       = context.new_module("exact_frem")
    int32_ty  = context.int32
    double_ty = context.double

    div = mod.functions.add("exact_div", [int32_ty, int32_ty], int32_ty)
    div.basic_blocks.append("entry") do |builder|
      builder.ret(builder.exact_udiv(div.params[0], div.params[1]))
    end

    rem = mod.functions.add("frem", [double_ty, double_ty], double_ty)
    rem.basic_blocks.append("entry") do |builder|
      builder.ret(builder.frem(rem.params[0], rem.params[1]))
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("udiv exact")
    ir.should contain("frem double")

    LLVMM::JITCompiler.new(mod) do |jit|
      run_div = Proc(Int32, Int32, Int32).new(jit.function_address("exact_div"), Pointer(Void).null)
      run_div.call(84, 2).should eq(42)
      run_rem = Proc(Float64, Float64, Float64).new(jit.function_address("frem"), Pointer(Void).null)
      run_rem.call(42.5, 2.0).should eq(0.5)
    end
  end

  it "builds freeze and global strings" do
    context  = LLVMM::Context.new
    mod      = context.new_module("freeze_gs")
    int32_ty = context.int32

    func = mod.functions.add("f", [] of LLVMM::Type, int32_ty)
    func.basic_blocks.append("entry") do |builder|
      frozen = builder.freeze(LLVMM::Value.new(LibLLVMM.get_undef(int32_ty)), "frozen")
      builder.global_string("hello llvmm", "greeting")
      builder.ret frozen
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("freeze i32 undef")
    ir.should contain("hello llvmm")
  end

  it "round-trips struct fields through struct_gep" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("struct_gep")
    int32_ty = context.int32
    point_ty = context.struct([int32_ty, int32_ty])

    func = mod.functions.add("sum", [int32_ty, int32_ty], int32_ty)
    func.basic_blocks.append("entry") do |builder|
      point = builder.alloca(point_ty, "point")
      x     = builder.struct_gep(point_ty, point, 0, "x")
      builder.store(func.params[0], x)
      y = builder.struct_gep(point_ty, point, 1, "y")
      builder.store(func.params[1], y)
      builder.ret(builder.add(builder.load(int32_ty, x), builder.load(int32_ty, y)))
    end

    mod.verify
    mod.to_s.should contain("getelementptr inbounds")

    LLVMM::JITCompiler.new(mod) do |jit|
      sum = Proc(Int32, Int32, Int32).new(jit.function_address("sum"), Pointer(Void).null)
      sum.call(19, 23).should eq(42)
    end
  end

  it "builds pointer null checks and differences" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("ptr_checks")
    int32_ty = context.int32
    int64_ty = context.int64

    check = mod.functions.add("check_null", [context.void_pointer], int32_ty)
    check.basic_blocks.append("entry") do |builder|
      is_null     = builder.is_null(check.params[0], "n")
      is_not_null = builder.is_not_null(check.params[0], "nn")
      x           = builder.zext(is_null, int32_ty)
      y           = builder.zext(is_not_null, int32_ty)
      builder.ret(builder.add(x, builder.add(y, y)))
    end

    diff = mod.functions.add("diff", [] of LLVMM::Type, int64_ty)
    diff.basic_blocks.append("entry") do |builder|
      arr_ty = int32_ty.array(4)
      arr    = builder.alloca(arr_ty, "arr")
      zero   = int32_ty.const_int(0)
      base   = builder.gep(arr_ty, arr, zero, zero, "base")
      third  = builder.gep(arr_ty, arr, zero, int32_ty.const_int(3), "third")
      builder.ret(builder.ptr_diff(int32_ty, third, base, "d"))
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("icmp eq ptr")
    ir.should contain("icmp ne ptr")
    ir.should contain("sdiv exact")

    cell = Pointer(Int32).malloc(1)
    LLVMM::JITCompiler.new(mod) do |jit|
      run_check = Proc(Pointer(Int32), Int32).new(jit.function_address("check_null"), Pointer(Void).null)
      run_check.call(Pointer(Int32).null).should eq(1)
      run_check.call(cell).should eq(2)

      run_diff = Proc(Int64).new(jit.function_address("diff"), Pointer(Void).null)
      run_diff.call.should eq(3_i64)
    end
  end

  it "returns aggregates" do
    context  = LLVMM::Context.new
    mod      = context.new_module("aggregate_ret")
    int32_ty = context.int32
    pair_ty  = context.struct([int32_ty, int32_ty])

    func = mod.functions.add("pair", [] of LLVMM::Type, pair_ty)
    func.basic_blocks.append("entry") do |builder|
      builder.aggregate_ret([int32_ty.const_int(19), int32_ty.const_int(23)])
    end

    mod.verify
    mod.to_s.should contain("ret { i32, i32 } { i32 19, i32 23 }")
  end

  it "round-trips heap memory through malloc and free" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("malloc_free")
    int32_ty = context.int32

    func = mod.functions.add("heap", [int32_ty], int32_ty)
    func.basic_blocks.append("entry") do |builder|
      cell = builder.malloc(int32_ty, "cell")
      builder.store(func.params[0], cell)
      value = builder.load(int32_ty, cell, "value")
      builder.free(cell)
      builder.ret value
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("malloc")
    ir.should contain("free")

    LLVMM::JITCompiler.new(mod) do |jit|
      heap = Proc(Int32, Int32).new(jit.function_address("heap"), Pointer(Void).null)
      heap.call(42).should eq(42)
    end
  end

  it "builds binops and casts from opcodes" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("opcode_builds")
    int32_ty = context.int32
    int64_ty = context.int64

    func = mod.functions.add("wide_sum", [int32_ty, int32_ty], int64_ty)
    func.basic_blocks.append("entry") do |builder|
      sum = builder.binop(LLVMM::Opcode::Add, func.params[0], func.params[1], "sum")
      builder.ret(builder.cast(LLVMM::Opcode::SExt, sum, int64_ty, "wide"))
    end

    mod.verify

    LLVMM::JITCompiler.new(mod) do |jit|
      wide_sum = Proc(Int32, Int32, Int64).new(jit.function_address("wide_sum"), Pointer(Void).null)
      wide_sum.call(40, 2).should eq(42_i64)
    end
  end

  it "builds the typed cast family" do
    LLVMM.init_native_target

    context   = LLVMM::Context.new
    mod       = context.new_module("casts")
    int32_ty  = context.int32
    int64_ty  = context.int64
    double_ty = context.double
    float_ty  = context.float

    sext_fn = mod.functions.add("signed_cast", [int32_ty], int64_ty)
    sext_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.int_cast(sext_fn.params[0], int64_ty, is_signed: true))
    end

    sext_or_fn = mod.functions.add("sext_or", [int32_ty], int64_ty)
    sext_or_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.sext_or_bit_cast(sext_or_fn.params[0], int64_ty))
    end

    zext_or_fn = mod.functions.add("zext_or", [int32_ty], int64_ty)
    zext_or_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.zext_or_bit_cast(zext_or_fn.params[0], int64_ty))
    end

    trunc_or_fn = mod.functions.add("trunc_or", [int64_ty], int32_ty)
    trunc_or_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.trunc_or_bit_cast(trunc_or_fn.params[0], int32_ty))
    end

    fp_fn = mod.functions.add("fp_cast", [double_ty], float_ty)
    fp_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.fp_cast(fp_fn.params[0], float_ty))
    end

    ptr_fn = mod.functions.add("ptr_cast", [context.void_pointer], context.void_pointer)
    ptr_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.pointer_cast(ptr_fn.params[0], context.void_pointer))
    end

    as1_ty  = LLVMM::Type.new(LibLLVMM.pointer_type_in_context(context, 1))
    addr_fn = mod.functions.add("addr_cast", [as1_ty], context.void_pointer)
    addr_fn.basic_blocks.append("entry") do |builder|
      builder.ret(builder.addr_space_cast(addr_fn.params[0], context.void_pointer))
    end

    mod.verify
    ir = mod.to_s
    ir.should contain("sext i32")
    ir.should contain("zext i32")
    ir.should contain("trunc i64")
    ir.should contain("fptrunc double")
    ir.should contain("addrspacecast ptr addrspace(1)")

    cell = Pointer(Int32).malloc(1)
    LLVMM::JITCompiler.new(mod) do |jit|
      signed_cast = Proc(Int32, Int64).new(jit.function_address("signed_cast"), Pointer(Void).null)
      signed_cast.call(-7).should eq(-7_i64)

      sext_or = Proc(Int32, Int64).new(jit.function_address("sext_or"), Pointer(Void).null)
      sext_or.call(-7).should eq(-7_i64)

      zext_or = Proc(Int32, Int64).new(jit.function_address("zext_or"), Pointer(Void).null)
      zext_or.call(-1).should eq(4294967295_i64)

      trunc_or = Proc(Int64, Int32).new(jit.function_address("trunc_or"), Pointer(Void).null)
      trunc_or.call((1_i64 << 33) + 42).should eq(42)

      fp_cast = Proc(Float64, Float32).new(jit.function_address("fp_cast"), Pointer(Void).null)
      fp_cast.call(42.5).should eq(42.5_f32)

      ptr_cast = Proc(Pointer(Int32), Pointer(Int32)).new(jit.function_address("ptr_cast"), Pointer(Void).null)
      ptr_cast.call(cell).should eq(cell)
    end
  end

  it "inserts detached instructions into a builder" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("insert")
    int32_ty = context.int32

    func  = mod.functions.add("f", [int32_ty], int32_ty)
    entry = func.basic_blocks.append("entry")

    scratch  = LLVMM::Builder.new(LibLLVMM.create_builder_in_context(context))
    plus_one = scratch.add(func.params[0], int32_ty.const_int(1))
    doubled  = scratch.mul(plus_one, int32_ty.const_int(2))

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.insert(plus_one, "plus_one")
    builder.insert(doubled)
    builder.ret doubled

    plus_one.name.should eq("plus_one")
    mod.verify

    LLVMM::JITCompiler.new(mod) do |jit|
      run = Proc(Int32, Int32).new(jit.function_address("f"), Pointer(Void).null)
      run.call(20).should eq(42)
    end
  end

  it "jumps through an indirect branch to an added destination" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("indirectbr")
    int32_ty = context.int32

    func   = mod.functions.add("f", [] of LLVMM::Type, int32_ty)
    entry  = func.basic_blocks.append("entry")
    target = func.basic_blocks.append("target")

    builder = context.new_builder
    builder.position_at_end(entry)
    ibr = builder.indirect_br(target.block_address, 1)
    builder.add_destination(ibr, target)

    builder.position_at_end(target)
    builder.ret int32_ty.const_int(42)

    mod.verify
    mod.to_s.should contain("indirectbr ptr blockaddress")

    LLVMM::JITCompiler.new(mod) do |jit|
      run = Proc(Int32).new(jit.function_address("f"), Pointer(Void).null)
      run.call.should eq(42)
    end
  end

  it "builds a cleanup funclet with cleanupret" do
    context = LLVMM::Context.new
    mod     = context.new_module("cleanupeh")

    personality = mod.functions.add("__C_specific_handler", [] of LLVMM::Type, context.int32)
    callee      = mod.functions.add("may_throw", [] of LLVMM::Type, context.void)

    func = mod.functions.add("wrapper", [] of LLVMM::Type, context.void)
    func.personality_function = personality

    entry      = func.basic_blocks.append("entry")
    cont       = func.basic_blocks.append("cont")
    cleanup_bb = func.basic_blocks.append("cleanup_bb")

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.invoke(callee.function_type, callee, [] of LLVMM::Value, cont, cleanup_bb)

    builder.position_at_end(cont)
    builder.ret

    builder.position_at_end(cleanup_bb)
    cp = builder.cleanup_pad(LLVMM::Value.null, [] of LLVMM::Value, "cp")
    builder.cleanup_ret(cp, LLVMM::BasicBlock.null)

    mod.verify
    ir = mod.to_s
    ir.should contain("cleanuppad within none")
    ir.should contain("cleanupret from %cp unwind to caller")
  end

  it "resumes unwinding from a landing pad" do
    context = LLVMM::Context.new
    mod     = context.new_module("resume")

    personality = mod.functions.add("__gxx_personality_v0", [] of LLVMM::Type, context.int32)
    callee      = mod.functions.add("may_throw", [] of LLVMM::Type, context.void)

    func = mod.functions.add("wrapper", [] of LLVMM::Type, context.void)
    func.personality_function = personality

    entry = func.basic_blocks.append("entry")
    cont  = func.basic_blocks.append("cont")
    lpad  = func.basic_blocks.append("lpad")

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.invoke(callee.function_type, callee, [] of LLVMM::Value, cont, lpad)

    builder.position_at_end(cont)
    builder.ret

    builder.position_at_end(lpad)
    lp_ty  = context.struct([context.void_pointer, context.int32])
    caught = builder.landing_pad(lp_ty, personality, [] of LLVMM::Value, "caught")
    builder.resume(caught)

    mod.verify
    mod.to_s.should contain("resume { ptr, i32 }")
  end

  it "applies a default fp math tag to floating point instructions" do
    context  = LLVMM::Context.new
    mod      = context.new_module("fpmath")
    float_ty = context.float

    func  = mod.functions.add("addf", [float_ty, float_ty], float_ty)
    entry = func.basic_blocks.append("entry")

    builder = context.new_builder
    builder.default_fp_math_tag.null?.should be_true

    builder.default_fp_math_tag = context.md_node([float_ty.const_double(4.0)])
    builder.default_fp_math_tag.null?.should be_false

    builder.position_at_end(entry)
    builder.ret(builder.fadd(func.params[0], func.params[1]))

    mod.verify
    mod.to_s.should contain("!fpmath")

    builder.clear_default_fp_math_tag
    builder.default_fp_math_tag.null?.should be_true
  end

  it "creates extended scalar, struct, and scalable vector types" do
    context = LLVMM::Context.new

    context.bfloat.kind.should eq(LLVMM::Type::Kind::BFloat)
    context.x86_amx.kind.should eq(LLVMM::Type::Kind::X86_AMX)
    context.token.kind.should eq(LLVMM::Type::Kind::Token)

    scalable = context.int32.scalable_vector(4)
    scalable.kind.should eq(LLVMM::Type::Kind::ScalableVector)
    scalable.element_type.should eq(context.int32)
    scalable.to_s.should contain("vscale x 4")

    pair = context.struct([context.int32, context.int8])
    pair.struct_element_type(0).should eq(context.int32)
    pair.struct_element_type(1).should eq(context.int8)
    pair.struct_element_types.should eq([context.int32, context.int8])
    expect_raises(Exception, "Not a Struct") { context.int32.struct_element_type(0) }

    global_context = LLVMM::Context.new(LibLLVMM.get_type_context(LibLLVMM.void_type), dispose_on_finalize: false)
    LLVMM::Type.new(LibLLVMM.void_type).kind.should eq(LLVMM::Type::Kind::Void)
    LLVMM::Type.new(LibLLVMM.bfloat_type).kind.should eq(LLVMM::Type::Kind::BFloat)
    LLVMM::Type.new(LibLLVMM.x86_fp80_type).kind.should eq(LLVMM::Type::Kind::X86_FP80)
    LLVMM::Type.new(LibLLVMM.x86_amx_type).kind.should eq(LLVMM::Type::Kind::X86_AMX)

    elements      = [global_context.int32.to_unsafe, global_context.int8.to_unsafe]
    global_struct = LLVMM::Type.new(LibLLVMM.struct_type(elements.to_unsafe.as(LibLLVMM::TypeRef*), elements.size, 0))
    global_struct.kind.should eq(LLVMM::Type::Kind::Struct)
    global_struct.struct_element_type(0).should eq(global_context.int32)
    global_struct.struct_element_type(1).should eq(global_context.int8)
  end

  it "clones modules independently" do
    context = LLVMM::Context.new
    mod     = context.new_module("clone_me")
    fn      = mod.functions.add("f", [context.int32], context.int32)
    fn.basic_blocks.append("entry") { |builder| builder.ret fn.params[0] }

    clone = mod.clone
    clone.to_unsafe.should_not eq(mod.to_unsafe)
    clone.to_s.should eq(mod.to_s)

    mod.functions.add("g", [] of LLVMM::Type, context.void)
    mod.functions["g"]?.should_not be_nil
    clone.functions["g"]?.should be_nil
    clone.to_s.should_not eq(mod.to_s)
  end

  it "round-trips module inline asm" do
    context = LLVMM::Context.new
    mod     = context.new_module("mod_asm")

    mod.inline_asm.should be_empty
    mod.inline_asm = ".globl my_sym"
    mod.inline_asm.should contain(".globl my_sym")
    mod.append_inline_asm("my_sym:")
    mod.inline_asm.should contain("my_sym:")
    mod.to_s.should contain("module asm")
  end

  it "round-trips the data layout string" do
    context = LLVMM::Context.new
    mod     = context.new_module("datalayout")

    layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
    mod.data_layout_string = layout
    mod.data_layout_string.should eq(layout)
    mod.to_s.should contain("target datalayout")
  end

  it "inserts, moves, removes, and re-appends basic blocks" do
    context = LLVMM::Context.new
    mod     = context.new_module("bb_mgmt")
    func    = mod.functions.add("f", [] of LLVMM::Type, context.void)

    entry = func.basic_blocks.append("entry")
    pre   = func.basic_blocks.insert_before(entry, "pre")
    last  = func.basic_blocks.append("last")

    func.basic_blocks.size.should eq(3)
    func.basic_blocks.map(&.name).should eq(["pre", "entry", "last"])

    last.move_before(pre)
    func.basic_blocks.map(&.name).should eq(["last", "pre", "entry"])

    pre.move_after(entry)
    func.basic_blocks.map(&.name).should eq(["last", "entry", "pre"])

    pre.remove_from_parent
    func.basic_blocks.size.should eq(2)
    func.basic_blocks.map(&.name).should eq(["last", "entry"])
    pre.parent.should be_nil

    func.basic_blocks.append_existing(pre)
    func.basic_blocks.size.should eq(3)
    func.basic_blocks.map(&.name).should eq(["last", "entry", "pre"])
    pre.parent.should_not be_nil
  end

  it "converts between values and basic blocks" do
    context = LLVMM::Context.new
    mod     = context.new_module("bb_values")
    func    = mod.functions.add("f", [] of LLVMM::Type, context.void)
    entry   = func.basic_blocks.append("entry")
    other   = func.basic_blocks.append("other")

    value = entry.to_value
    value.basic_block?.should be_true
    value.kind.should eq(LLVMM::Value::Kind::BasicBlock)
    value.to_basic_block.to_unsafe.should eq(entry.to_unsafe)

    func.to_value.basic_block?.should be_false

    blocks = Pointer(LibLLVMM::BasicBlockRef).malloc(2)
    LibLLVMM.get_basic_blocks(func, blocks)
    blocks[0].should eq(entry.to_unsafe)
    blocks[1].should eq(other.to_unsafe)
  end

  it "reports parse errors through the diagnostic handler" do
    context     = LLVMM::Context.new
    diagnostics = [] of {LLVMM::DiagnosticSeverity, String}
    context.on_diagnostic { |severity, message| diagnostics << {severity, message} }

    expect_raises(Exception) do
      LLVMM::Module.parse(LLVMM::MemoryBuffer.create("this is not bitcode".to_slice), context)
    end

    diagnostics.should_not be_empty
    diagnostics.first[0].should eq(LLVMM::DiagnosticSeverity::Error)
    diagnostics.first[1].should contain("Invalid bitcode signature")
  end

  it "discards value names when requested" do
    context = LLVMM::Context.new
    context.discard_value_names?.should be_false
    context.discard_value_names = true
    context.discard_value_names?.should be_true

    mod  = context.new_module("discard_names")
    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      builder.ret(builder.add(func.params[0], context.int32.const_int(1), "sum"))
    end

    mod.to_s.should_not contain("sum")
  end

  it "reports the LLVM version and host CPU features" do
    major = LLVMM.version.split('.').first.to_i
    major.should be >= 18

    LLVMM.host_cpu_features.should_not be_empty
    LLVMM.host_cpu_features.should contain("+")
  end

  it "reports target capabilities and toggles target machine settings" do
    LLVMM.init_native_target

    triple = LLVMM.default_target_triple
    target = LLVMM::Target.from_triple(triple)
    target.has_jit?.should be_true
    target.has_target_machine?.should be_true
    target.has_asm_backend?.should be_true

    machine = target.create_target_machine(triple, LLVMM.host_cpu_name)
    machine.asm_verbosity = false
    machine.fast_isel = false
    machine.global_isel_abort = LLVMM::GlobalISelAbortMode::Disable
    machine.machine_outliner = true

    context = LLVMM::Context.new
    mod     = context.new_module("tm_setters")
    fn      = mod.functions.add("answer", [] of LLVMM::Type, context.int32)
    fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

    machine.emit_obj_to_memory_buffer(mod).to_slice.size.should be > 0
  end

  it "creates an equivalent target machine through options" do
    LLVMM.init_native_target

    triple = LLVMM.default_target_triple
    target = LLVMM::Target.from_triple(triple)
    cpu    = LLVMM.host_cpu_name

    classic     = target.create_target_machine(triple, cpu)
    options     = LLVMM::TargetMachineOptions.new(cpu: cpu)
    via_options = target.create_target_machine_with_options(triple, options)

    via_options.triple.should eq(classic.triple)
    via_options.cpu.should eq(classic.cpu)

    context = LLVMM::Context.new
    mod     = context.new_module("tm_options")
    fn      = mod.functions.add("answer", [] of LLVMM::Type, context.int32)
    fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

    classic_asm = String.new(classic.emit_asm_to_memory_buffer(mod).to_slice)
    options_asm = String.new(via_options.emit_asm_to_memory_buffer(mod).to_slice)
    options_asm.should eq(classic_asm)
  end

  it "disassembles machine code for the host target" do
    LLVMM.init_native_target

    triple = LLVMM.default_target_triple
    bytes =
      if triple.starts_with?("x86_64") || triple.starts_with?("i386") || triple.starts_with?("i686")
        Bytes[0x48, 0x83, 0xC0, 0x2A, 0xC3]
      elsif triple.starts_with?("aarch64")
        Bytes[0x84, 0x0A, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6]
      else
        raise "no reference instruction encoding for #{triple}"
      end

    disassembler = LLVMM::Disassembler.new(triple, cpu: LLVMM.host_cpu_name, features: "")
    instructions = disassembler.disassemble(bytes)
    instructions.size.should be >= 2
    instructions.last.text.should contain("ret")
    instructions.sum(&.size).should eq(bytes.size)

    LLVMM::Disassembler.new(triple).disassemble(bytes).last.text.should contain("ret")
    LLVMM::Disassembler.new(triple, cpu: LLVMM.host_cpu_name).disassemble(bytes).last.text.should contain("ret")

    disassembler.disassemble(Bytes.empty).should be_empty

    disassembler.options = LLVMM::Disassembler::Option::PrintImmHex
    disassembler.disassemble(bytes).first.text.should contain("0x2a")

    disassembler.dispose
    disassembler.dispose

    expect_raises(Exception, /Failed to create disassembler/) do
      LLVMM::Disassembler.new("not-a-real-triple-zzz")
    end
  end
end

describe "instruction mutators and getters" do
  it "reads and replaces instruction operands" do
    context = LLVMM::Context.new
    mod     = context.new_module("operands")
    func    = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      add = builder.add(func.params[0], context.int32.const_int(1), "add")
      add.operand(0).should eq(func.params[0].to_value)
      add.operand(1).const_int_get_zext_value.should eq(1)
      add.operand_use(0).null?.should be_false
      add.set_operand(1, context.int32.const_int(2))
      add.operand(1).const_int_get_zext_value.should eq(2)
      builder.ret add
    end
    mod.verify
  end

  it "round-trips nsw, nuw, exact and in_bounds flags" do
    context = LLVMM::Context.new
    mod     = context.new_module("arith_flags")
    func    = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      add = builder.add(func.params[0], func.params[0], "add")
      add.nsw.should be_false
      add.nsw = true
      add.nsw.should be_true
      add.nuw.should be_false
      add.nuw = true
      add.nuw.should be_true

      nsw_add = builder.nsw_add(func.params[0], add, "nsw_add")
      nsw_add.nsw.should be_true
      nsw_add.nsw = false
      nsw_add.nsw.should be_false

      div = builder.udiv(func.params[0], add, "div")
      div.exact.should be_false
      div.exact = true
      div.exact.should be_true

      ptr = builder.alloca(context.int32, "p")
      gep = builder.gep(context.int32, ptr, context.int32.const_int(0), "gep")
      gep.in_bounds?.should be_false
      gep.in_bounds = true
      gep.in_bounds?.should be_true
      inbounds = builder.inbounds_gep(context.int32, ptr, context.int32.const_int(0), "igep")
      inbounds.in_bounds?.should be_true

      builder.ret add
    end
    mod.verify
  end

  it "reads and mutates branch conditions and successors" do
    context = LLVMM::Context.new
    mod     = context.new_module("branches")
    func    = mod.functions.add("f", [context.int32], context.int32)

    entry   = func.basic_blocks.append("entry")
    then_bb = func.basic_blocks.append("then")
    else_bb = func.basic_blocks.append("else")
    merge   = func.basic_blocks.append("merge")

    builder = context.new_builder
    builder.position_at_end(entry)
    c1 = builder.icmp(LLVMM::IntPredicate::SGT, func.params[0], context.int32.const_int(0), "c1")
    c2 = builder.icmp(LLVMM::IntPredicate::SLT, func.params[0], context.int32.const_int(0), "c2")
    br = builder.cond(c1, then_bb, else_bb)

    br.conditional?.should be_true
    br.num_successors.should eq(2)
    br.condition.should eq(c1)
    br.successor(0).should eq(then_bb)
    br.successor(1).should eq(else_bb)

    br.condition = c2
    br.condition.should eq(c2)
    br.set_successor(1, merge)
    br.successor(1).should eq(merge)

    builder.position_at_end(then_bb)
    ubr = builder.br(merge)
    ubr.conditional?.should be_false
    ubr.num_successors.should eq(1)
    ubr.successor(0).should eq(merge)

    builder.position_at_end(else_bb)
    builder.ret func.params[0]

    builder.position_at_end(merge)
    builder.ret func.params[0]

    mod.verify
  end

  it "reads and mutates call instructions and call-site attributes" do
    context = LLVMM::Context.new
    mod     = context.new_module("calls")
    callee  = mod.functions.add("callee", [context.int32], context.int32)
    callee.basic_blocks.append("entry") { |builder| builder.ret callee.params[0] }

    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      call = builder.call(callee.function_type, callee, [func.params[0]], "call")

      call.called_value.should eq(callee.to_value)
      call.called_function_type.should eq(callee.function_type)

      call.tail_call?.should be_false
      call.tail_call_kind.should eq(LLVMM::TailCallKind::None)
      call.tail_call = true
      call.tail_call?.should be_true
      call.tail_call_kind.should eq(LLVMM::TailCallKind::Tail)
      call.tail_call_kind = LLVMM::TailCallKind::NoTail
      call.tail_call?.should be_false
      call.tail_call_kind.should eq(LLVMM::TailCallKind::NoTail)
      call.tail_call_kind = LLVMM::TailCallKind::None

      fn_idx = LLVMM::AttributeIndex::FunctionIndex
      call.call_site_attribute_count(fn_idx).should eq(0)
      call.add_instruction_attribute(fn_idx.value, LLVMM::Attribute::NoUnwind, context)
      call.call_site_attribute_count(fn_idx).should eq(1)
      call.call_site_attributes(fn_idx).size.should eq(1)
      call.call_site_enum_attribute(fn_idx, LLVMM::Attribute::NoUnwind).should_not be_nil
      call.remove_call_site_enum_attribute(fn_idx, LLVMM::Attribute::NoUnwind)
      call.call_site_enum_attribute(fn_idx, LLVMM::Attribute::NoUnwind).should be_nil
      call.call_site_attribute_count(fn_idx).should eq(0)

      str_attr = LibLLVMM.create_string_attribute(context, "callee-saved", 12, "yes", 3)
      LibLLVMM.add_call_site_attribute(call, 0, str_attr)
      call.call_site_string_attribute(0, "callee-saved").should_not be_nil
      call.call_site_string_attribute(0, "nope").should be_nil
      call.remove_call_site_string_attribute(0, "callee-saved")
      call.call_site_string_attribute(0, "callee-saved").should be_nil

      builder.ret call
    end
    mod.verify
  end

  it "enumerates operand bundles on call instructions" do
    context = LLVMM::Context.new
    mod     = context.new_module("bundles")
    callee  = mod.functions.add("callee", [context.int32], context.int32)
    callee.basic_blocks.append("entry") { |builder| builder.ret callee.params[0] }

    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      bundle = builder.build_operand_bundle_def("deopt", [context.int32.const_int(7)])
      call   = builder.call(callee.function_type, callee, [func.params[0]], "bundled", bundle)
      bundle.dispose

      call.num_operand_bundles.should eq(1)
      read = call.operand_bundle_at_index(0)
      read.tag.should eq("deopt")
      read.num_args.should eq(1)
      read.arg_at_index(0).const_int_get_zext_value.should eq(7)

      plain = builder.call(callee.function_type, callee, [func.params[0]], "plain")
      plain.num_operand_bundles.should eq(0)

      builder.ret call
    end
    mod.verify
  end

  it "reads and mutates atomic and memory instruction properties" do
    context  = LLVMM::Context.new
    mod      = context.new_module("atomic_props")
    int32_ty = context.int32
    func     = mod.functions.add("f", [context.void_pointer, int32_ty], int32_ty)
    func.basic_blocks.append("entry") do |builder|
      rmw = builder.atomicrmw(LLVMM::AtomicRMWBinOp::Add, func.params[0], func.params[1], LLVMM::AtomicOrdering::SequentiallyConsistent, false)
      rmw.atomicrmw_bin_op.should eq(LLVMM::AtomicRMWBinOp::Add)
      rmw.atomicrmw_bin_op = LLVMM::AtomicRMWBinOp::Xchg
      rmw.atomicrmw_bin_op.should eq(LLVMM::AtomicRMWBinOp::Xchg)
      rmw.ordering.should eq(LLVMM::AtomicOrdering::SequentiallyConsistent)
      rmw.ordering = LLVMM::AtomicOrdering::Acquire
      rmw.ordering.should eq(LLVMM::AtomicOrdering::Acquire)
      rmw.atomic_single_thread?.should be_false
      rmw.atomic_single_thread = true
      rmw.atomic_single_thread?.should be_true

      cx = builder.cmpxchg(func.params[0], func.params[1], int32_ty.const_int(0), LLVMM::AtomicOrdering::Acquire, LLVMM::AtomicOrdering::Monotonic)
      cx.cmpxchg_success_ordering.should eq(LLVMM::AtomicOrdering::Acquire)
      cx.cmpxchg_failure_ordering.should eq(LLVMM::AtomicOrdering::Monotonic)
      cx.cmpxchg_success_ordering = LLVMM::AtomicOrdering::SequentiallyConsistent
      cx.cmpxchg_failure_ordering = LLVMM::AtomicOrdering::Acquire
      cx.cmpxchg_success_ordering.should eq(LLVMM::AtomicOrdering::SequentiallyConsistent)
      cx.cmpxchg_failure_ordering.should eq(LLVMM::AtomicOrdering::Acquire)
      cx.atomic_single_thread?.should be_false

      st = builder.store_volatile(func.params[1], func.params[0])
      st.volatile?.should be_true
      st.volatile = false
      st.volatile?.should be_false

      ld = builder.load(int32_ty, func.params[0], "ld")
      ld.volatile?.should be_false
      ld.alignment = 8
      ld.alignment.should eq(8)

      builder.ret rmw
    end
    mod.verify
  end

  it "reads icmp/fcmp predicates and computes cast opcodes" do
    context = LLVMM::Context.new
    mod     = context.new_module("predicates")
    func    = mod.functions.add("f", [context.int32], context.int1)
    func.basic_blocks.append("entry") do |builder|
      cmp = builder.icmp(LLVMM::IntPredicate::SGT, func.params[0], context.int32.const_int(0), "cmp")
      cmp.icmp_predicate.should eq(LLVMM::IntPredicate::SGT)
      builder.ret cmp
    end

    g = mod.functions.add("g", [context.double], context.int1)
    g.basic_blocks.append("entry") do |builder|
      fcmp = builder.fcmp(LLVMM::RealPredicate::OEQ, g.params[0], g.params[0], "fcmp")
      fcmp.fcmp_predicate.should eq(LLVMM::RealPredicate::OEQ)
      builder.ret fcmp
    end

    func.params[0].cast_opcode(context.int64, src_is_signed: true, dest_is_signed: true).should eq(LLVMM::Opcode::SExt)
    func.params[0].cast_opcode(context.int64).should eq(LLVMM::Opcode::ZExt)
    func.params[0].cast_opcode(context.double, src_is_signed: true).should eq(LLVMM::Opcode::SIToFP)
    func.params[0].cast_opcode(context.double).should eq(LLVMM::Opcode::UIToFP)

    mod.verify
  end

  it "round-trips fast-math flags on floating point instructions" do
    context = LLVMM::Context.new
    mod     = context.new_module("fmf")
    func    = mod.functions.add("f", [context.double], context.double)
    func.basic_blocks.append("entry") do |builder|
      sum = builder.fadd(func.params[0], func.params[0], "sum")
      sum.can_use_fast_math_flags?.should be_true
      sum.fast_math_flags.should eq(LLVMM::FastMathFlags.new(0_u32))
      sum.fast_math_flags = LLVMM::FastMathFlags::NoNaNs | LLVMM::FastMathFlags::NoInfs
      sum.fast_math_flags.should eq(LLVMM::FastMathFlags::NoNaNs | LLVMM::FastMathFlags::NoInfs)
      builder.ret sum
    end

    g = mod.functions.add("g", [context.int32], context.int32)
    g.basic_blocks.append("entry") do |builder|
      add = builder.add(g.params[0], g.params[0], "add")
      add.can_use_fast_math_flags?.should be_false
      builder.ret add
    end
    mod.verify
  end

  it "reads catchswitch handlers, catchpad parents and personality functions" do
    context = LLVMM::Context.new
    mod     = context.new_module("eh_read")

    personality = mod.functions.add("__C_specific_handler", [] of LLVMM::Type, context.int32)
    callee      = mod.functions.add("may_throw", [] of LLVMM::Type, context.void)

    func = mod.functions.add("wrapper", [] of LLVMM::Type, context.void)
    func.has_personality_fn?.should be_false
    func.personality_function = personality
    func.has_personality_fn?.should be_true
    func.personality_fn.should eq(personality.to_value)

    entry  = func.basic_blocks.append("entry")
    cont   = func.basic_blocks.append("cont")
    cs_bb  = func.basic_blocks.append("cs_bb")
    cs2_bb = func.basic_blocks.append("cs2_bb")
    cp_bb  = func.basic_blocks.append("cp_bb")
    cp2_bb = func.basic_blocks.append("cp2_bb")

    builder = context.new_builder
    builder.position_at_end(entry)
    builder.invoke(callee.function_type, callee, [] of LLVMM::Value, cont, cs_bb)

    builder.position_at_end(cont)
    builder.ret

    builder.position_at_end(cs_bb)
    cs = builder.catch_switch(LLVMM::Value.null, cs2_bb, 1, "cs")

    builder.position_at_end(cs2_bb)
    cs2 = builder.catch_switch(LLVMM::Value.null, LLVMM::BasicBlock.null, 1, "cs2")

    g1 = mod.globals.add(context.int32, "g1")
    g2 = mod.globals.add(context.int32, "g2")

    builder.position_at_end(cp_bb)
    cp = builder.catch_pad(cs, [g1], "cp")
    builder.build_catch_ret(cp, cont)
    builder.add_handler(cs, cp_bb)

    builder.position_at_end(cp2_bb)
    cp2 = builder.catch_pad(cs2, [] of LLVMM::Value, "cp2")
    builder.build_catch_ret(cp2, cont)
    builder.add_handler(cs2, cp2_bb)

    cs.num_handlers.should eq(1)
    cs.handlers.should eq([cp_bb])
    cs2.handlers.should eq([cp2_bb])

    cp.parent_catch_switch.should eq(cs.to_value)
    cp2.parent_catch_switch.should eq(cs2.to_value)
    cp2.parent_catch_switch = cs
    cp2.parent_catch_switch.should eq(cs.to_value)
    cp2.parent_catch_switch = cs2
    cp2.parent_catch_switch.should eq(cs2.to_value)

    cp.arg_operand(0).should eq(g1)
    cp.set_arg_operand(0, g2)
    cp.arg_operand(0).should eq(g2)

    mod.verify
  end
end

describe "debug info FFI and value metadata" do
  it "creates extended DIBuilder descriptors and reads them back" do
    context = LLVMM::Context.new
    mod     = context.new_module("di_extended")
    di      = LLVMM::DIBuilder.new(mod)
    file    = di.create_file("ext.cr", "/src")
    cu      = di.create_compile_unit(LLVMM::DwarfSourceLanguage::Crystal, "ext.cr", "/src", "llvmm-spec", false, "", 0)

    int_di = di.create_basic_type("Int32", 32, 32, LLVMM::DwarfTypeEncoding::Signed)
    ptr_di = di.create_pointer_type(int_di, 64, 64, "Int32*")

    typedef    = di.create_typedef(int_di, "MyInt", file, 4, cu)
    typedef_md = LLVMM::Metadata.new(typedef, context)
    typedef_md.name.should eq("MyInt")
    typedef_md.type_line.should eq(4)
    typedef_md.kind.should eq(LLVMM::MetadataKind::DIDerivedType)
    typedef_md.di_node_tag.should eq(22)

    qualified = di.create_qualified_type(38, int_di)
    LLVMM::Metadata.new(qualified, context).di_node_tag.should eq(38)
    reference = di.create_reference_type(16, int_di)
    LLVMM::Metadata.new(reference, context).di_node_tag.should eq(16)

    subrange     = di.get_or_create_array_subrange(0, 4)
    vector       = di.create_vector_type(128, 32, int_di, [subrange])
    vector_flags = LLVMM::Metadata.new(vector, context).flags
    (vector_flags.value & LLVMM::DIFlags::Vector.value).should_not eq(0)

    artificial = di.create_artificial_type(int_di)
    (LLVMM::Metadata.new(artificial, context).flags.value & LLVMM::DIFlags::Artificial.value).should_not eq(0)

    object_ptr = di.create_object_pointer_type(ptr_di, implicit: false)
    (LLVMM::Metadata.new(object_ptr, context).flags.value & LLVMM::DIFlags::ObjectPointer.value).should_not eq(0)

    LLVMM::Metadata.new(di.create_nullptr_type, context).kind.should eq(LLVMM::MetadataKind::DIBasicType)

    forward    = di.create_forward_decl(19, "Fwd", cu, file, 9)
    forward_md = LLVMM::Metadata.new(forward, context)
    forward_md.name.should eq("Fwd")
    (forward_md.flags.value & LLVMM::DIFlags::FwdDecl.value).should_not eq(0)

    base     = di.create_struct_type(cu, "Base", file, 5, 32, 32, LLVMM::DIFlags::Zero, nil, [] of LibLLVMM::MetadataRef)
    member   = di.create_member_type(cu, "x", file, 6, 32, 32, 0, LLVMM::DIFlags::Zero, int_di)
    klass    = di.create_class_type(cu, "Widget", file, 7, 64, 32, 0, LLVMM::DIFlags::Zero, nil, [member])
    klass_md = LLVMM::Metadata.new(klass, context)
    klass_md.name.should eq("Widget")
    klass_md.size_in_bits.should eq(64)
    {% if LibLLVMM::IS_LT_200 %}
      klass_md.di_node_tag.should eq(19)
    {% else %}
      klass_md.di_node_tag.should eq(2)
    {% end %}

    inheritance = di.create_inheritance(klass, base, 0, 0_u32, LLVMM::DIFlags::Public)
    LLVMM::Metadata.new(inheritance, context).di_node_tag.should eq(28)
    derived = di.create_class_type(cu, "Derived", file, 8, 64, 32, 0, LLVMM::DIFlags::Zero, nil, [inheritance, member])
    derived.null?.should be_false

    bitfield = di.create_bitfield_member_type(klass, "bf", file, 10, 3, 5, 0, LLVMM::DIFlags::Zero, int_di)
    (LLVMM::Metadata.new(bitfield, context).flags.value & LLVMM::DIFlags::BitField.value).should_not eq(0)

    di.create_static_member_type(klass, "Count", file, 11, int_di, LLVMM::DIFlags::StaticMember).null?.should be_false
    di.create_member_pointer_type(int_di, klass, 64, 64).null?.should be_false

    property = di.create_objc_property("prop", file, 12, "prop", "setProp:", 0, int_di)
    property.null?.should be_false
    di.create_objc_ivar("_prop", file, 12, 32, 32, 0, LLVMM::DIFlags::Zero, int_di, property).null?.should be_false

    namespace = di.create_namespace(cu, "std")
    LLVMM::Metadata.new(namespace, context).kind.should eq(LLVMM::MetadataKind::DINamespace)
    di_module = di.create_module(cu, "M", config_macros: "-DNDEBUG", include_path: "/mod")
    LLVMM::Metadata.new(di_module, context).kind.should eq(LLVMM::MetadataKind::DIModule)

    im_ns    = di.create_imported_module_from_namespace(cu, namespace, file, 13)
    im_alias = di.create_imported_module_from_alias(cu, im_ns, file, 14)
    im_mod   = di.create_imported_module_from_module(cu, di_module, file, 15)
    im_decl  = di.create_imported_declaration(cu, typedef, file, 16, "Alias")
    {im_ns, im_alias, im_mod, im_decl}.each do |imported|
      LLVMM::Metadata.new(imported, context).kind.should eq(LLVMM::MetadataKind::DIImportedEntity)
    end

    macro_file = di.create_temp_macro_file(nil, 1, file)
    macro_node = di.create_macro(macro_file, 2, LLVMM::DWARFMacinfoRecordType::Define, "FOO", "1")
    LLVMM::Metadata.new(macro_node, context).kind.should eq(LLVMM::MetadataKind::DIMacro)

    cve = di.create_constant_value_expression(42_u64)
    LLVMM::Metadata.new(cve, context).kind.should eq(LLVMM::MetadataKind::DIExpression)

    tmp_gv  = di.create_temp_global_variable_fwd_decl(cu, "tmpgv", "tmpgv", file, 17, int_di, false)
    real_gv = di.create_global_variable_expression(cu, "tmpgv", "tmpgv", file, 17, int_di, false)
    di.replace_temporary(tmp_gv, real_gv)

    di.end
    mod.verify
  end

  it "round-trips DI node getters, subprograms and module debug state" do
    context = LLVMM::Context.new
    mod     = context.new_module("di_getters")
    mod.add_flag(LibLLVMM::ModuleFlagBehavior::Error, "Debug Info Version", LLVMM::DEBUG_METADATA_VERSION)

    di   = LLVMM::DIBuilder.disallow_unresolved(mod)
    file = di.create_file("test.cr", "/src")
    cu   = di.create_compile_unit(LLVMM::DwarfSourceLanguage::Crystal, "test.cr", "/src", "llvmm-spec", false, "", 0)

    file_md = LLVMM::Metadata.new(file, context)
    file_md.filename.should eq("test.cr")
    file_md.directory.should eq("/src")
    file_md.file_source.should eq("")
    file_md.kind.should eq(LLVMM::MetadataKind::DIFile)

    int_di = di.create_basic_type("Int32", 32, 32, LLVMM::DwarfTypeEncoding::Signed)
    sub_ty = di.create_subroutine_type(file, [int_di])

    m1        = di.create_member_type(cu, "a", file, 7, 32, 32, 0, LLVMM::DIFlags::Zero, int_di)
    m2        = di.create_member_type(cu, "b", file, 8, 32, 32, 32, LLVMM::DIFlags::Zero, int_di)
    struct_di = di.create_struct_type(cu, "Pair", file, 6, 64, 32, LLVMM::DIFlags::Zero, nil, [m1, m2])

    struct_md = LLVMM::Metadata.new(struct_di, context)
    struct_md.name.should eq("Pair")
    struct_md.size_in_bits.should eq(64)
    struct_md.align_in_bits.should eq(32)
    struct_md.type_line.should eq(6)
    struct_md.flags.should eq(LLVMM::DIFlags::Zero)
    struct_md.kind.should eq(LLVMM::MetadataKind::DICompositeType)
    struct_md.di_node_tag.should eq(19)

    member_md = LLVMM::Metadata.new(m2, context)
    member_md.name.should eq("b")
    member_md.offset_in_bits.should eq(32)

    func       = mod.functions.add("answer", [] of LLVMM::Type, context.int32)
    entry      = func.basic_blocks.append("entry")
    subprogram = di.create_function(cu, "answer", "answer", file, 1, sub_ty, false, true, 1, LLVMM::DIFlags::Prototyped, false, func)
    sp_md      = LLVMM::Metadata.new(subprogram, context)
    sp_md.subprogram_line.should eq(1)
    sp_md.kind.should eq(LLVMM::MetadataKind::DISubprogram)
    sp_md.scope_file.filename.should eq("test.cr")

    read_back = func.subprogram.not_nil!
    read_back.should eq(sp_md)
    read_back.di_node_tag.should eq(46)

    loc    = di.create_debug_location(3, 2, subprogram)
    loc_md = LLVMM::Metadata.new(loc, context)
    loc_md.location_line.should eq(3)
    loc_md.location_column.should eq(2)
    loc_md.location_scope.should eq(sp_md)
    loc_md.location_inlined_at.should be_nil

    outer    = di.create_debug_location(9, 4, subprogram, inlined_at: loc)
    outer_md = LLVMM::Metadata.new(outer, context)
    outer_md.location_line.should eq(9)
    outer_md.location_inlined_at.not_nil!.location_line.should eq(3)

    auto_var = di.create_auto_variable(subprogram, "x", file, 3, struct_di, 32)
    var_md   = LLVMM::Metadata.new(auto_var, context)
    var_md.variable_line.should eq(3)
    var_md.variable_file.filename.should eq("test.cr")
    var_md.variable_scope.should eq(sp_md)

    gv = mod.globals.add(context.int32, "g")
    gv.initializer = context.int32.const_int(7)
    gve = di.create_global_variable_expression(cu, "g", "g", file, 2, int_di, false)
    gv.global_set_metadata("dbg", gve)
    gve_md = LLVMM::Metadata.new(gve, context)
    gve_md.kind.should eq(LLVMM::MetadataKind::DIGlobalVariableExpression)
    gve_md.gve_variable.kind.should eq(LLVMM::MetadataKind::DIGlobalVariable)
    gve_md.gve_expression.kind.should eq(LLVMM::MetadataKind::DIExpression)

    builder = context.new_builder
    builder.position_at_end(entry)
    storage = builder.alloca(context.int32, "x")
    di.insert_declare_at_end(storage, auto_var, di.create_expression(nil, 0), loc, entry)
    loaded = builder.load(context.int32, storage)

    loaded.debug_loc.should be_nil
    loaded.debug_loc = loc
    read_loc = loaded.debug_loc.not_nil!
    read_loc.location_line.should eq(3)
    read_loc.location_column.should eq(2)
    read_loc.location_scope.should eq(sp_md)
    loaded.debug_loc = nil
    loaded.debug_loc.should be_nil
    loaded.debug_loc = loc
    builder.ret loaded

    di.finalize_subprogram(subprogram)
    di.end
    mod.verify

    mod.debug_metadata_version.should eq(LLVMM::DEBUG_METADATA_VERSION)
    LLVMM.debug_metadata_version.should be > 0
    mod.strip_debug_info.should be_true
    mod.to_s.should_not contain("DISubprogram")
  end

  it "attaches, enumerates and replaces instruction metadata" do
    context = LLVMM::Context.new
    mod     = context.new_module("inst_metadata")
    func    = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      add = builder.add(func.params[0], context.int32.const_int(1), "add")
      add.has_metadata?.should be_false

      md       = context.md_node([context.int32.const_int(7)])
      md_value = LLVMM::Value.new(LibLLVMM.metadata_as_value(context, md))
      md_value.value_as_metadata?.should_not be_nil
      kind_id = LibLLVMM.get_md_kind_id_in_context(context, "my.kind", 7)
      add.set_metadata(kind_id, md_value)
      add.has_metadata?.should be_true
      add.metadata(kind_id).should_not be_nil
      add.metadata("my.kind").should_not be_nil
      add.metadata("no.such.kind").should be_nil

      entries = add.all_metadata_other_than_debug_loc
      entries.size.should eq(1)
      entries[0][0].should eq(kind_id)
      LLVMM::Metadata.new(entries[0][1], context).kind.should eq(LLVMM::MetadataKind::MDTuple)

      seen = false
      add.each_metadata_other_than_debug_loc do |kind, entry_md|
        kind.should eq(kind_id)
        entry_md.null?.should be_false
        seen = true
      end
      seen.should be_true

      context.metadata_type.kind.should eq(LLVMM::Type::Kind::Metadata)

      one = LibLLVMM.value_as_metadata(context.int32.const_int(1))
      two = LibLLVMM.value_as_metadata(context.int32.const_int(2))
      tmp = context.temporary_md_node([one, one])
      LLVMM::Metadata.new(tmp, context).kind.should eq(LLVMM::MetadataKind::MDTuple)

      holder = LLVMM::Value.new(LibLLVMM.metadata_as_value(context, tmp))
      holder.value_as_metadata?.should be_nil
      holder.replace_md_node_operand_with(0_u32, two)

      LibLLVMM.get_md_node_num_operands(holder).should eq(2)
      dest = uninitialized LibLLVMM::ValueRef[2]
      LibLLVMM.get_md_node_operands(holder, dest.to_unsafe)
      LLVMM::Value.new(dest[0]).const_int_get_zext_value.should eq(2)
      LLVMM::Value.new(dest[1]).const_int_get_zext_value.should eq(1)

      add.value_as_metadata?.should be_nil

      LLVMM::Metadata.new(tmp, context).dispose_temporary

      builder.ret add
    end
    mod.verify
  end
end

require "file_utils"

private ORC_SPEC_EXPORTED = LibLLVMM::JITSymbolFlags.new(
  generic_flags: LibLLVMM::JITSymbolGenericFlags::Exported.value | LibLLVMM::JITSymbolGenericFlags::Callable.value,
  target_flags: 0_u8)

fun llvmm_orc_spec_main : Int32
  42
end

fun llvmm_orc_spec_extra : Int32
  7
end

fun llvmm_orc_spec_replaced : Int32
  11
end

fun llvmm_orc_spec_generated : Int32
  23
end

fun llvmm_orc_spec_lazy_target : Int32
  42
end

private class OrcSpecGlobals
  class_property error_handler_called = false
end

fun llvmm_orc_spec_error_handler : Int32
  OrcSpecGlobals.error_handler_called = true
  -1
end

private class OrcSpecState
  property es        = Pointer(Void).null
  property obj_layer = Pointer(Void).null
  property ir_layer  = Pointer(Void).null
  property ir_module : LLVMM::Module?                 = nil
  property ts_ctx    : LLVMM::Orc::ThreadSafeContext? = nil
  property obj_bytes         = Bytes.empty
  property symbol_names      = [] of String
  property requested_names   = [] of String
  property generated_names   = [] of String
  property errors            = [] of String
  property target_dylib_seen = false
  property session_seen      = false
  property initializer_null  = false
  property destroyed         = 0
end

private def orc_spec_error_string(err : LibLLVMM::ErrorRef) : String
  chars = LibLLVMM.get_error_message(err)
  String.new(chars).tap { LibLLVMM.dispose_error_message(chars) }
end

private def orc_spec_context : Tuple(LLVMM::Orc::ThreadSafeContext, LLVMM::Context)
  {% if LibLLVMM::IS_LT_210 %}
    ts_ctx = LLVMM::Orc::ThreadSafeContext.new
    {ts_ctx, ts_ctx.context}
  {% else %}
    context = LLVMM::Context.new
    {LLVMM::Orc::ThreadSafeContext.new(context), context}
  {% end %}
end

describe "Orc/LLJIT extras and error handling" do
  it "exposes LLJIT getters, JITTargetMachineBuilder and the symbol string pool" do
    LLVMM.init_native_target

    builder        = LLVMM::Orc::LLJITBuilder.new
    creator_called = false
    builder.set_object_linking_layer_creator do |es, triple|
      creator_called = true
      LibLLVMM::OrcObjectLayerRef.null
    end
    creator_called.should be_false
    builder.dispose

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)

    lljit.triple_string.should_not be_empty
    lljit.data_layout_string.should_not be_empty

    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
    lljit.data_layout_string.should eq(machine.data_layout.to_data_layout_string)

    LibLLVMM.orc_jit_target_machine_builder_detect_host(out jtmb).null?.should be_true
    detected = LLVMM.string_and_dispose(LibLLVMM.orc_jit_target_machine_builder_get_target_triple(jtmb))
    detected.should eq(lljit.triple_string)
    LibLLVMM.orc_jit_target_machine_builder_set_target_triple(jtmb, "wasm32-unknown-unknown")
    LLVMM.string_and_dispose(LibLLVMM.orc_jit_target_machine_builder_get_target_triple(jtmb)).should eq("wasm32-unknown-unknown")
    LibLLVMM.orc_dispose_jit_target_machine_builder(jtmb)

    es = lljit.execution_session
    es["main"].not_nil!.to_unsafe.should eq(lljit.main_jit_dylib.to_unsafe)
    es["no_such_dylib"].should be_nil

    bare = es.create_bare_jit_dylib("bare_lib")
    es["bare_lib"].not_nil!.to_unsafe.should eq(bare.to_unsafe)
    named = es.create_jit_dylib("named_lib")
    es["named_lib"].not_nil!.to_unsafe.should eq(named.to_unsafe)

    mangled  = lljit.mangle_and_intern("mangle_me")
    expected = lljit.global_prefix == '_' ? "_mangle_me" : "mangle_me"
    mangled.to_s.should eq(expected)
    mangled.retain
    mangled.release
    mangled.release

    interned = es.intern("plain_sym")
    interned.to_s.should eq("plain_sym")
    again = es.intern("plain_sym")
    again.to_unsafe.should eq(interned.to_unsafe)
    interned.release
    again.release

    es.symbol_string_pool.clear_dead_entries

    lljit.dispose
  end

  it "manages resource trackers, the IR transform layer and ThreadSafeModule" do
    LLVMM.init_native_target

    ts_ctx, context = orc_spec_context
    mod = context.new_module("rt_tracked_mod")
    mod.target = LLVMM.default_target_triple
    fn = mod.functions.add("rt_tracked", [] of LLVMM::Type, context.int32)
    fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib

    transform_calls = 0
    module_names    = [] of String
    ir_layer        = lljit.ir_transform_layer
    ir_layer.set_transform do |tsm, mr|
      transform_calls += 1
      tsm.with_module_do do |m|
        module_names << m.name
        nil
      end
    end

    tracker = main.create_resource_tracker
    lljit.add_llvm_ir_module_with_rt(tracker, LLVMM::Orc::ThreadSafeModule.new(mod, ts_ctx))

    address = lljit.lookup("rt_tracked")
    Proc(Int32).new(address, Pointer(Void).null).call.should eq(42)
    transform_calls.should eq(1)
    module_names.should eq(["rt_tracked_mod"])

    default_tracker = main.default_resource_tracker
    expect_raises(Exception, "borrowed") { default_tracker.release }
    other = main.create_resource_tracker
    tracker.transfer_to(other)
    tracker.release

    other.remove
    expect_raises(Exception) { lljit.lookup("rt_tracked") }
    other.release

    main.clear
    ir_layer.to_unsafe.should_not eq(Pointer(Void).null)
    lljit.dispose
    ts_ctx.dispose
  end

  it "adds object files through LLJIT and object layer APIs with a dump-objects transform" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)

    make_obj = ->(mod_name : String, fn_name : String) {
      mod = context.new_module(mod_name)
      fn  = mod.functions.add(fn_name, [] of LLVMM::Type, context.int32)
      fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }
      machine.emit_obj_to_memory_buffer(mod)
    }

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib

    dump_dir = File.tempname("llvmm_dump")
    Dir.mkdir(dump_dir)
    begin
      dump = LibLLVMM.orc_create_dump_objects(dump_dir, "llvmm_spec_obj")
      dump.null?.should be_false

      transform_hits = 0
      obj_transform  = lljit.obj_transform_layer
      obj_transform.set_transform do |buf|
        transform_hits += 1
        LibLLVMM.orc_dump_objects_call_operator(dump, buf)
      end

      lljit.add_object_file(main, make_obj.call("obj_mod_a", "obj_answer_a"))
      Proc(Int32).new(lljit.lookup("obj_answer_a"), Pointer(Void).null).call.should eq(42)
      transform_hits.should eq(1)

      tracker = main.create_resource_tracker
      lljit.add_object_file_with_rt(tracker, make_obj.call("obj_mod_b", "obj_answer_b"))
      Proc(Int32).new(lljit.lookup("obj_answer_b"), Pointer(Void).null).call.should eq(42)
      transform_hits.should eq(2)
      tracker.release

      obj_layer = lljit.obj_linking_layer
      obj_layer.add_object_file(main, make_obj.call("obj_mod_c", "obj_answer_c"))
      Proc(Int32).new(lljit.lookup("obj_answer_c"), Pointer(Void).null).call.should eq(42)
      transform_hits.should eq(2)

      tracker2 = main.create_resource_tracker
      obj_layer.add_object_file_with_rt(tracker2, make_obj.call("obj_mod_d", "obj_answer_d"))
      Proc(Int32).new(lljit.lookup("obj_answer_d"), Pointer(Void).null).call.should eq(42)
      tracker2.release

      transform_hits.should eq(2)
      Dir.children(dump_dir).size.should be >= 2

      lljit.dispose
      LibLLVMM.orc_dispose_dump_objects(dump)
      obj_transform.to_unsafe.should_not eq(Pointer(Void).null)
    ensure
      FileUtils.rm_rf(dump_dir)
    end
  end

  it "exercises string errors and execution session lookups" do
    LLVMM.init_native_target

    err = LLVMM::Error.string("boom")
    err.type_id.should eq(LLVMM::Error.string_type_id)
    err.message.should eq("boom")

    LLVMM::Error.string("swallowed").consume

    ts_ctx, context = orc_spec_context
    mod = context.new_module("es_lookup_mod")
    mod.target = LLVMM.default_target_triple
    fn = mod.functions.add("es_target", [] of LLVMM::Type, context.int32)
    fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib
    lljit.add_llvm_ir_module(main, LLVMM::Orc::ThreadSafeModule.new(mod, ts_ctx))

    es = lljit.execution_session

    results = Channel(String).new(2)
    handler = ->(err : LibLLVMM::ErrorRef, result : LibLLVMM::OrcCSymbolMapPairs, num : LibC::SizeT) {
      if err.null?
        results.send("ok:#{result[0].address}")
      else
        results.send("err:#{orc_spec_error_string(err)}")
      end
    }
    boxed = Box.box(handler)
    callback = ->(err : LibLLVMM::ErrorRef, result : LibLLVMM::OrcCSymbolMapPairs, num : LibC::SizeT, ctx : Void*) {
      Box(Proc(LibLLVMM::ErrorRef, LibLLVMM::OrcCSymbolMapPairs, LibC::SizeT, Nil)).unbox(ctx).call(err, result, num)
    }

    search_order = StaticArray(LibLLVMM::OrcCJITDylibSearchOrderElement, 1).new {
      LibLLVMM::OrcCJITDylibSearchOrderElement.new(jd: main.to_unsafe, jd_lookup_flags: LibLLVMM::OrcJITDylibLookupFlags::MatchExportedSymbolsOnly)
    }

    wanted = es.intern("es_target")
    lookup_set = StaticArray(LibLLVMM::OrcCLookupSetElement, 1).new {
      LibLLVMM::OrcCLookupSetElement.new(name: wanted.to_unsafe, lookup_flags: LibLLVMM::OrcSymbolLookupFlags::RequiredSymbol)
    }
    LibLLVMM.orc_execution_session_lookup(es, LibLLVMM::OrcLookupKind::Static, search_order.to_unsafe, 1, lookup_set.to_unsafe, 1, callback, boxed)

    expected = lljit.lookup("es_target")
    select
    when msg = results.receive
      msg.should eq("ok:#{expected.address}")
    when timeout(10.seconds)
      raise "execution session lookup timed out"
    end

    missing = es.intern("es_missing_target")
    miss_set = StaticArray(LibLLVMM::OrcCLookupSetElement, 1).new {
      LibLLVMM::OrcCLookupSetElement.new(name: missing.to_unsafe, lookup_flags: LibLLVMM::OrcSymbolLookupFlags::RequiredSymbol)
    }
    LibLLVMM.orc_execution_session_lookup(es, LibLLVMM::OrcLookupKind::Static, search_order.to_unsafe, 1, miss_set.to_unsafe, 1, callback, boxed)
    select
    when msg = results.receive
      msg.should start_with("err:")
      msg.should contain("es_missing_target")
    when timeout(10.seconds)
      raise "execution session lookup timed out"
    end

    boxed.should_not eq(Pointer(Void).null)
    lljit.dispose
    ts_ctx.dispose
  end

  it "materializes symbols through custom materialization units" do
    LLVMM.init_native_target

    ts_ctx, context = orc_spec_context

    ir_mod = context.new_module("cmu_ir_mod")
    ir_mod.target = LLVMM.default_target_triple
    ir_fn = ir_mod.functions.add("cmu_ir_fn", [] of LLVMM::Type, context.int32)
    ir_fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
    obj_mod = context.new_module("cmu_obj_mod")
    obj_fn  = obj_mod.functions.add("cmu_obj_fn", [] of LLVMM::Type, context.int32)
    obj_fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }
    obj_bytes = machine.emit_obj_to_memory_buffer(obj_mod).to_slice.dup

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib
    es    = lljit.execution_session

    state = OrcSpecState.new
    state.es = es.to_unsafe
    state.obj_layer = lljit.obj_linking_layer.to_unsafe
    state.ir_layer = lljit.ir_transform_layer.to_unsafe
    state.ir_module = ir_mod
    state.ts_ctx = ts_ctx
    state.obj_bytes = obj_bytes
    state_box = Box.box(state)

    discard = ->(ctx : Void*, jd : LibLLVMM::OrcJITDylibRef, sym : LibLLVMM::OrcSymbolStringPoolEntryRef) { }
    destroy = ->(ctx : Void*) { Box(OrcSpecState).unbox(ctx).destroyed += 1 }

    manual = ->(ctx : Void*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      st = Box(OrcSpecState).unbox(ctx)
      st.target_dylib_seen = !LibLLVMM.orc_materialization_responsibility_get_target_dylib(mr).null?
      session = LibLLVMM.orc_materialization_responsibility_get_execution_session(mr)
      st.session_seen = !session.null?

      flags = LibLLVMM.orc_materialization_responsibility_get_symbols(mr, out num_pairs)
      num_pairs.times { |i| st.symbol_names << String.new(LibLLVMM.orc_symbol_string_pool_entry_str(flags[i].name)) }
      LibLLVMM.orc_dispose_c_symbol_flags_map(flags)

      st.initializer_null = LibLLVMM.orc_materialization_responsibility_get_initializer_symbol(mr).null?

      requested = LibLLVMM.orc_materialization_responsibility_get_requested_symbols(mr, out num_requested)
      num_requested.times { |i| st.requested_names << String.new(LibLLVMM.orc_symbol_string_pool_entry_str(requested[i])) }
      LibLLVMM.orc_dispose_symbols(requested)

      extra_flags = LibLLVMM::OrcCSymbolFlagsMapPairs.malloc(1)
      extra_flags[0] = LibLLVMM::OrcCSymbolFlagsMapPair.new(name: LibLLVMM.orc_execution_session_intern(session, "cmu_extra"), flags: ORC_SPEC_EXPORTED)
      if err = LibLLVMM.orc_materialization_responsibility_define_materializing(mr, extra_flags, 1)
        st.errors << orc_spec_error_string(err)
        LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
        LibLLVMM.orc_dispose_materialization_responsibility(mr)
      else
        {% if LibLLVMM::IS_LT_190 %}
          LibLLVMM.orc_materialization_responsibility_add_dependencies(mr,
            LibLLVMM.orc_execution_session_intern(session, "cmu_main"),
            Pointer(LibLLVMM::OrcCDependenceMapPair).null, 0)
        {% end %}

        delegate_syms = Pointer(LibLLVMM::OrcSymbolStringPoolEntryRef).malloc(1)
        delegate_syms[0] = LibLLVMM.orc_execution_session_intern(session, "cmu_extra")
        if err = LibLLVMM.orc_materialization_responsibility_delegate(mr, delegate_syms, 1, out delegated)
          st.errors << orc_spec_error_string(err)
          LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
          LibLLVMM.orc_dispose_materialization_responsibility(mr)
        else
          resolved = LibLLVMM::OrcCSymbolMapPairs.malloc(1)
          resolved[0] = LibLLVMM::OrcCSymbolMapPair.new(name: LibLLVMM.orc_execution_session_intern(session, "cmu_main"), address: (->llvmm_orc_spec_main).pointer.address)
          if err = LibLLVMM.orc_materialization_responsibility_notify_resolved(mr, resolved, 1)
            st.errors << orc_spec_error_string(err)
            LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
          else
            emit_err = {% if LibLLVMM::IS_LT_190 %}
                         LibLLVMM.orc_materialization_responsibility_notify_emitted(mr)
                       {% else %}
                         LibLLVMM.orc_materialization_responsibility_notify_emitted(mr, Pointer(LibLLVMM::OrcCSymbolDependenceGroup).null, 0)
                       {% end %}
            if emit_err
              st.errors << orc_spec_error_string(emit_err)
              LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
            end
          end
          LibLLVMM.orc_dispose_materialization_responsibility(mr)

          resolved2 = LibLLVMM::OrcCSymbolMapPairs.malloc(1)
          resolved2[0] = LibLLVMM::OrcCSymbolMapPair.new(name: LibLLVMM.orc_execution_session_intern(session, "cmu_extra"), address: (->llvmm_orc_spec_extra).pointer.address)
          if err = LibLLVMM.orc_materialization_responsibility_notify_resolved(delegated, resolved2, 1)
            st.errors << orc_spec_error_string(err)
          else
            emit_err2 = {% if LibLLVMM::IS_LT_190 %}
                          LibLLVMM.orc_materialization_responsibility_notify_emitted(delegated)
                        {% else %}
                          LibLLVMM.orc_materialization_responsibility_notify_emitted(delegated, Pointer(LibLLVMM::OrcCSymbolDependenceGroup).null, 0)
                        {% end %}
            st.errors << orc_spec_error_string(emit_err2) if emit_err2
          end
          LibLLVMM.orc_dispose_materialization_responsibility(delegated)
        end
      end
    }

    replace_mat = ->(ctx : Void*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      st      = Box(OrcSpecState).unbox(ctx)
      session = LibLLVMM.orc_materialization_responsibility_get_execution_session(mr)
      pair    = LibLLVMM::OrcCSymbolMapPairs.malloc(1)
      pair[0] = LibLLVMM::OrcCSymbolMapPair.new(name: LibLLVMM.orc_execution_session_intern(session, "cmu_replaced"), address: (->llvmm_orc_spec_replaced).pointer.address)
      mu = LibLLVMM.orc_absolute_symbols(pair, 1)
      if err = LibLLVMM.orc_materialization_responsibility_replace(mr, mu)
        st.errors << orc_spec_error_string(err)
        LibLLVMM.orc_dispose_materialization_unit(mu)
        LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
      end
      LibLLVMM.orc_dispose_materialization_responsibility(mr)
    }

    ir_emit = ->(ctx : Void*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      st  = Box(OrcSpecState).unbox(ctx)
      tsm = LLVMM::Orc::ThreadSafeModule.new(st.ir_module.not_nil!, st.ts_ctx.not_nil!)
      tsm.take_ownership { st.errors << "tsm already owned" }
      LibLLVMM.orc_ir_transform_layer_emit(st.ir_layer, mr, tsm)
    }

    obj_emit = ->(ctx : Void*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      st     = Box(OrcSpecState).unbox(ctx)
      buffer = LLVMM::MemoryBuffer.create_copy(st.obj_bytes, "cmu_obj")
      buffer.take_ownership { st.errors << "buffer already owned" }
      LibLLVMM.orc_object_layer_emit(st.obj_layer, mr, buffer.to_unsafe)
    }

    fail_mat = ->(ctx : Void*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      LibLLVMM.orc_materialization_responsibility_fail_materialization(mr)
      LibLLVMM.orc_dispose_materialization_responsibility(mr)
    }

    define_mu = ->(name : String, materialize : LibLLVMM::OrcMaterializationUnitMaterializeFunction) {
      entry = LibLLVMM.orc_execution_session_intern(es, name.check_no_null_byte)
      syms  = LibLLVMM::OrcCSymbolFlagsMapPairs.malloc(1)
      syms[0] = LibLLVMM::OrcCSymbolFlagsMapPair.new(name: entry, flags: ORC_SPEC_EXPORTED)
      mu = LibLLVMM.orc_create_custom_materialization_unit(name.check_no_null_byte, state_box, syms, 1, nil, materialize, discard, destroy)
      LibLLVMM.orc_jit_dylib_define(main, mu).null?.should be_true
    }

    define_mu.call("cmu_main", manual)
    define_mu.call("cmu_replaced", replace_mat)
    define_mu.call("cmu_ir_fn", ir_emit)
    define_mu.call("cmu_obj_fn", obj_emit)
    define_mu.call("cmu_fail", fail_mat)

    unused_syms = LibLLVMM::OrcCSymbolFlagsMapPairs.malloc(1)
    unused_syms[0] = LibLLVMM::OrcCSymbolFlagsMapPair.new(name: LibLLVMM.orc_execution_session_intern(es, "cmu_unused"), flags: ORC_SPEC_EXPORTED)
    unused_mu = LibLLVMM.orc_create_custom_materialization_unit("cmu_unused", state_box, unused_syms, 1, nil, manual, discard, destroy)
    LibLLVMM.orc_dispose_materialization_unit(unused_mu)
    state.destroyed.should eq(1)

    Proc(Int32).new(lljit.lookup("cmu_main"), Pointer(Void).null).call.should eq(42)
    Proc(Int32).new(lljit.lookup("cmu_extra"), Pointer(Void).null).call.should eq(7)
    Proc(Int32).new(lljit.lookup("cmu_replaced"), Pointer(Void).null).call.should eq(11)
    Proc(Int32).new(lljit.lookup("cmu_ir_fn"), Pointer(Void).null).call.should eq(42)
    Proc(Int32).new(lljit.lookup("cmu_obj_fn"), Pointer(Void).null).call.should eq(42)
    expect_raises(Exception) { lljit.lookup("cmu_fail") }

    state.errors.should be_empty
    state.target_dylib_seen.should be_true
    state.session_seen.should be_true
    state.initializer_null.should be_true
    state.symbol_names.should eq(["cmu_main"])
    state.requested_names.should contain("cmu_main")

    lljit.dispose
    ts_ctx.dispose
    state.destroyed.should eq(1)
  end

  it "generates definitions with custom and library search generators" do
    LLVMM.init_native_target

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib
    es    = lljit.execution_session

    state = OrcSpecState.new
    state.es = es.to_unsafe
    state_box = Box.box(state)

    try_generate = ->(gen : LibLLVMM::OrcDefinitionGeneratorRef, ctx : Void*, lookup_state : LibLLVMM::OrcLookupStateRef*, kind : LibLLVMM::OrcLookupKind, jd : LibLLVMM::OrcJITDylibRef, jd_flags : LibLLVMM::OrcJITDylibLookupFlags, set : LibLLVMM::OrcCLookupSet, set_size : LibC::SizeT) {
      st      = Box(OrcSpecState).unbox(ctx)
      defined = false
      error   = Pointer(Void).null.as(LibLLVMM::ErrorRef)
      set_size.times do |i|
        name = String.new(LibLLVMM.orc_symbol_string_pool_entry_str(set[i].name))
        st.generated_names << name
        if name == "gen_answer"
          pair = LibLLVMM::OrcCSymbolMapPairs.malloc(1)
          pair[0] = LibLLVMM::OrcCSymbolMapPair.new(name: LibLLVMM.orc_execution_session_intern(st.es, "gen_answer"), address: (->llvmm_orc_spec_generated).pointer.address)
          mu = LibLLVMM.orc_absolute_symbols(pair, 1)
          if err = LibLLVMM.orc_jit_dylib_define(jd, mu)
            st.errors << orc_spec_error_string(err)
            LibLLVMM.orc_dispose_materialization_unit(mu)
            error = LibLLVMM.create_string_error("definition failed")
          else
            defined = true
          end
        end
      end
      if error.null? && defined
        saved = lookup_state.value
        lookup_state.value = Pointer(Void).null
        LibLLVMM.orc_lookup_state_continue_lookup(saved, Pointer(Void).null.as(LibLLVMM::ErrorRef))
      end
      error
    }

    generator = LLVMM::Orc::DefinitionGenerator.custom(try_generate, state_box)
    main.add_generator(generator)

    spare = LLVMM::Orc::DefinitionGenerator.custom(try_generate)
    spare.dispose

    main.link_symbols_from_current_process(lljit.global_prefix) { |name| name == "puts" }

    Proc(Int32).new(lljit.lookup("gen_answer"), Pointer(Void).null).call.should eq(23)
    state.generated_names.should contain("gen_answer")

    puts_addr = lljit.lookup("puts")
    puts_addr.should_not eq(Pointer(Void).null)
    expect_raises(Exception) { lljit.lookup("strlen") }

    state.errors.should be_empty
    main.to_unsafe.should_not eq(Pointer(Void).null)
    lljit.dispose
    state.generated_names.should contain("strlen")
  end

  it "links symbols from a static library archive" do
    {% if LibLLVMM::IS_LT_210 %}
      LLVMM.init_native_target
      lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
      expect_raises(NotImplementedError) do
        lljit.main_jit_dylib.link_symbols_from_static_library("nope.a", lljit.obj_linking_layer)
      end
      lljit.dispose
    {% else %}
      LLVMM.init_native_target

      context = LLVMM::Context.new
      triple = LLVMM.default_target_triple
      machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
      mod = context.new_module("static_lib_mod")
      fn = mod.functions.add("static_answer", [] of LLVMM::Type, context.int32)
      fn.basic_blocks.append("entry") { |builder| builder.ret(context.int32.const_int(42)) }

      obj_path = File.tempname("llvmm_static", ".o")
      lib_path = File.tempname("llvmm_static", ".a")
      begin
        machine.emit_obj_to_file(mod, obj_path).should be_true
        Process.run("ar", ["rcs", lib_path, obj_path]).success?.should be_true

        lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
        main = lljit.main_jit_dylib
        main.link_symbols_from_static_library(lib_path, lljit.obj_linking_layer)
        Proc(Int32).new(lljit.lookup("static_answer"), Pointer(Void).null).call.should eq(42)
        lljit.dispose
      ensure
        File.delete(obj_path) if File.exists?(obj_path)
        File.delete(lib_path) if File.exists?(lib_path)
      end
    {% end %}
  end

  it "resolves lazy reexports and reports failures through the error reporter" do
    LLVMM.init_native_target

    lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
    main  = lljit.main_jit_dylib
    es    = lljit.execution_session

    reported = [] of String
    es.on_error { |err| reported << err.message }

    pair = LibLLVMM::OrcCSymbolMapPairs.malloc(1)
    pair[0] = LibLLVMM::OrcCSymbolMapPair.new(name: LibLLVMM.orc_execution_session_intern(es, "lazy_target"), address: (->llvmm_orc_spec_lazy_target).pointer.address)
    LibLLVMM.orc_jit_dylib_define(main, LibLLVMM.orc_absolute_symbols(pair, 1)).null?.should be_true

    OrcSpecGlobals.error_handler_called = false
    triple = lljit.triple_string
    ism    = LibLLVMM.orc_create_local_indirect_stubs_manager(triple)
    ism.null?.should be_false
    LibLLVMM.orc_create_local_lazy_call_through_manager(triple, es, (->llvmm_orc_spec_error_handler).pointer.address, out lctm).null?.should be_true

    aliases = LibLLVMM::OrcCSymbolAliasMapPairs.malloc(2)
    aliases[0] = LibLLVMM::OrcCSymbolAliasMapPair.new(
      name: LibLLVMM.orc_execution_session_intern(es, "lazy_alias"),
      entry: LibLLVMM::OrcCSymbolAliasMapEntry.new(name: LibLLVMM.orc_execution_session_intern(es, "lazy_target"), flags: ORC_SPEC_EXPORTED))
    aliases[1] = LibLLVMM::OrcCSymbolAliasMapPair.new(
      name: LibLLVMM.orc_execution_session_intern(es, "lazy_missing"),
      entry: LibLLVMM::OrcCSymbolAliasMapEntry.new(name: LibLLVMM.orc_execution_session_intern(es, "lazy_missing_target"), flags: ORC_SPEC_EXPORTED))
    LibLLVMM.orc_jit_dylib_define(main, LibLLVMM.orc_lazy_reexports(lctm, ism, main, aliases, 2)).null?.should be_true

    Proc(Int32).new(lljit.lookup("lazy_alias"), Pointer(Void).null).call.should eq(42)

    missing = lljit.lookup("lazy_missing")
    Proc(Int32).new(missing, Pointer(Void).null).call.should eq(-1)
    OrcSpecGlobals.error_handler_called.should be_true
    reported.should_not be_empty
    reported.join(", ").should contain("lazy_missing_target")

    lljit.dispose
    LibLLVMM.orc_dispose_lazy_call_through_manager(lctm)
    LibLLVMM.orc_dispose_indirect_stubs_manager(ism)
    es.to_unsafe.should_not eq(Pointer(Void).null)
  end
end

describe "Core globals family and constant-expression tail" do
  it "round-trips global properties and walks globals in insertion order" do
    context = LLVMM::Context.new
    mod     = context.new_module("globals")
    g1      = mod.globals.add(context.int32, "g1")
    g1.initializer = context.int32.const_int(1)
    g2 = mod.globals.add_in_address_space(context.int32, "g2", 1)
    g2.initializer = context.int32.const_int(2)

    g1.section = ".rodata"
    g1.section.should eq(".rodata")
    g1.visibility = LLVMM::Visibility::Hidden
    g1.visibility.should eq(LLVMM::Visibility::Hidden)
    g1.dll_storage_class = LLVMM::DLLStorageClass::DLLExport
    g1.dll_storage_class.should eq(LLVMM::DLLStorageClass::DLLExport)
    g1.unnamed_address = LLVMM::UnnamedAddress::Global
    g1.unnamed_address.should eq(LLVMM::UnnamedAddress::Global)
    g1.thread_local = true
    g1.thread_local_mode = LLVMM::ThreadLocalMode::InitialExecTLS
    g1.thread_local_mode.should eq(LLVMM::ThreadLocalMode::InitialExecTLS)
    g1.externally_initialized = true
    g1.externally_initialized?.should be_true

    mod.globals.first.not_nil!.name.should eq("g1")
    mod.globals.last.not_nil!.name.should eq("g2")
    names = [] of String
    mod.globals.each { |g| names << g.name }
    names.should eq(["g1", "g2"])
    g1.next_global.not_nil!.name.should eq("g2")
    g2.previous_global.not_nil!.name.should eq("g1")

    ir = mod.to_s
    ir.should contain(%(section ".rodata"))
    ir.should contain("hidden")
    ir.should contain("dllexport")
    ir.should contain("unnamed_addr")
    ir.should contain("thread_local(initialexec)")
    ir.should contain("externally_initialized")
    ir.should contain("addrspace(1)")

    g2.delete_global
    mod.globals["g2"]?.should be_nil
  end

  it "creates aliases, retargets aliasees and iterates" do
    context = LLVMM::Context.new
    mod     = context.new_module("aliases")
    g1      = mod.globals.add(context.int32, "target1")
    g1.initializer = context.int32.const_int(1)
    g2 = mod.globals.add(context.int32, "target2")
    g2.initializer = context.int32.const_int(2)

    a1 = mod.add_global_alias(context.int32, g1, "alias1")
    a2 = mod.add_global_alias(context.int32, g2, "alias2")
    a1.aliasee.name.should eq("target1")
    a1.aliasee = g2
    a1.aliasee.name.should eq("target2")

    mod.named_global_alias("alias1").should_not be_nil
    mod.named_global_alias("nope").should be_nil

    names = [] of String
    mod.each_global_alias { |a| names << a.name }
    names.should eq(["alias1", "alias2"])
    LibLLVMM.get_last_global_alias(mod).should eq(a2.to_unsafe)
    LibLLVMM.get_previous_global_alias(a2).should eq(a1.to_unsafe)

    mod.to_s.should contain("@alias1 = alias i32, ptr @target2")
  end

  it "creates ifuncs, swaps resolvers and removes/erases them" do
    context  = LLVMM::Context.new
    mod      = context.new_module("ifuncs")
    fn_ty    = LLVMM::Type.function([] of LLVMM::Type, context.int32)
    resolver = mod.functions.add("resolver", [] of LLVMM::Type, context.pointer)

    if1 = mod.add_global_ifunc("if1", fn_ty, resolver)
    if2 = mod.add_global_ifunc("if2", fn_ty, resolver)
    if1.ifunc_resolver.name.should eq("resolver")
    if1.ifunc_resolver = resolver

    mod.named_global_ifunc("if1").should_not be_nil
    mod.named_global_ifunc("nope").should be_nil
    names = [] of String
    mod.each_global_ifunc { |f| names << f.name }
    names.should eq(["if1", "if2"])
    LibLLVMM.get_last_global_ifunc(mod).should eq(if2.to_unsafe)
    LibLLVMM.get_previous_global_ifunc(if2).should eq(if1.to_unsafe)

    mod.to_s.should contain("@if1 = ifunc")

    if2.remove_ifunc
    mod.named_global_ifunc("if2").should be_nil
    if1.erase_ifunc
    mod.named_global_ifunc("if1").should be_nil
  end

  it "manages named metadata nodes and operands" do
    context = LLVMM::Context.new
    mod     = context.new_module("named_md")
    nmd     = mod.named_metadata.get_or_insert("my.md")
    nmd.name.should eq("my.md")
    mod.named_metadata["my.md"].name.should eq("my.md")
    mod.named_metadata["missing"]?.should be_nil

    node = LLVMM::Value.new(LibLLVMM.metadata_as_value(context, context.md_node([context.int32.const_int(7)])))
    mod.named_metadata.add_operand("my.md", node)
    mod.named_metadata.num_operands("my.md").should eq(1)
    mod.named_metadata.operands("my.md").size.should eq(1)

    mod.named_metadata.get_or_insert("other.md")
    names = [] of String
    mod.named_metadata.each { |n| names << n.name }
    names.should eq(["my.md", "other.md"])
    mod.named_metadata.first.not_nil!.name.should eq("my.md")
    mod.named_metadata.last.not_nil!.name.should eq("other.md")
    mod.named_metadata.first.not_nil!.next.not_nil!.name.should eq("other.md")
    mod.named_metadata.last.not_nil!.previous.not_nil!.name.should eq("my.md")

    mod.to_s.should contain("!my.md = !{!0}")
  end

  it "round-trips module flags" do
    context = LLVMM::Context.new
    mod     = context.new_module("flags")
    mod.add_flag(LibLLVMM::ModuleFlagBehavior::Error, "my.flag", 7)
    mod.add_flag(LibLLVMM::ModuleFlagBehavior::Warning, "other.flag", context.int32.const_int(3))

    flags = mod.module_flags
    flags.size.should eq(2)
    flag = flags.find { |(behavior, key, _)| key == "my.flag" }.not_nil!
    flag[0].should eq(LibLLVMM::ModuleFlagBehavior::Error)
    flag[2].kind.should eq(LLVMM::MetadataKind::ConstantAsMetadata)

    mod.module_flag("my.flag").should_not be_nil
    mod.module_flag("nope").should be_nil
    mod.to_s.should contain(%(!"my.flag"))
  end

  it "applies the builder's current debug location to an instruction" do
    context = LLVMM::Context.new
    mod     = context.new_module("md_inst")
    mod.add_flag(LibLLVMM::ModuleFlagBehavior::Error, "Debug Info Version", LLVMM::DEBUG_METADATA_VERSION)

    di     = LLVMM::DIBuilder.new(mod)
    file   = di.create_file("test.cr", "/src")
    cu     = di.create_compile_unit(LLVMM::DwarfSourceLanguage::Crystal, "test.cr", "/src", "llvmm-spec", false, "", 0)
    sub_ty = di.create_subroutine_type(file, [] of LibLLVMM::MetadataRef)

    fn         = mod.functions.add("f", [context.float], context.float)
    entry      = fn.basic_blocks.append("entry")
    subprogram = di.create_function(cu, "f", "f", file, 1, sub_ty, false, true, 1, LLVMM::DIFlags::Zero, true, fn)
    loc        = di.create_debug_location(5, 4, subprogram)

    builder = context.new_builder
    builder.position_at_end(entry)
    sum = builder.fadd(fn.params[0], fn.params[0], "sum")
    sum.debug_loc.should be_nil

    builder.set_current_debug_location(loc, context)
    builder.set_inst_debug_location(sum)
    sum.debug_loc.not_nil!.location_line.should eq(5)
    builder.clear_current_debug_location

    builder.ret sum
    di.end
    mod.verify
  end

  it "copies, erases and clears global metadata" do
    context = LLVMM::Context.new
    mod     = context.new_module("gmd")
    g       = mod.globals.add(context.int32, "g")
    g.initializer = context.int32.const_int(0)
    g.global_set_metadata("kind.one", context.md_node([context.int32.const_int(1)]))
    g.global_set_metadata("kind.two", context.md_node([context.int32.const_int(2)]))

    g.copy_all_metadata.size.should eq(2)
    g.erase_metadata("kind.one")
    g.copy_all_metadata.size.should eq(1)
    g.clear_metadata
    g.copy_all_metadata.should be_empty
  end

  it "builds constant expressions" do
    context = LLVMM::Context.new
    mod     = context.new_module("consts")

    i32    = context.int32
    arr_ty = i32.array(4)
    g      = mod.globals.add(arr_ty, "arr")
    g.initializer = arr_ty.const_array([i32.const_int(10), i32.const_int(20), i32.const_int(30), i32.const_int(40)])

    zero = i32.const_int(0)
    one  = i32.const_int(1)
    gep  = g.const_gep(arr_ty, [zero, one])
    gep.inspect.should contain("getelementptr")
    g.const_in_bounds_gep(arr_ty, [zero, one]).inspect.should contain("inbounds")

    vec  = context.const_vector([i32.const_int(1), i32.const_int(2), i32.const_int(3), i32.const_int(4)])
    elem = vec.const_extract_element(i32.const_int(2))
    elem.const_int_get_zext_value.should eq(3)
    vec2 = vec.const_insert_element(i32.const_int(9), i32.const_int(0))
    mask = context.const_vector([i32.const_int(0), i32.const_int(5)])
    vec.const_shuffle_vector(vec2, mask).inspect.should eq("<2 x i32> <i32 1, i32 2>")

    struct_ty = context.struct([i32, context.float], "Pair")
    named     = struct_ty.const_named_struct([i32.const_int(7), context.float.const_float(1.5_f32)])
    named.inspect.should contain("%Pair")

    i32.const_int("ff", 16).const_int_get_zext_value.should eq(255)
    from_string = LibLLVMM.const_int_of_string(context.int64, "123", 10)
    LibLLVMM.const_int_get_zext_value(from_string).should eq(123)

    val, loses = context.fp128.const_double("0.1").const_real_get_double
    val.should be_close(0.1, 1e-12)
    loses.should be_true
    val, loses = context.double.const_double(0.5).const_real_get_double
    val.should eq(0.5)
    loses.should be_false
  end

  {% unless LibLLVMM::IS_LT_190 %}
    it "builds ConstantPtrAuth constants" do
      context = LLVMM::Context.new
      mod = context.new_module("ptrauth")
      fn = mod.functions.add("sign_me", [] of LLVMM::Type, context.void)
      fn.basic_blocks.append("entry") { |builder| builder.ret }

      pa = context.const_ptr_auth(fn, context.int32.const_int(0), context.int16.const_int(0x1234), context.int32.const_int(0))
      pa.to_unsafe.null?.should be_false
      pa.inspect.should contain("ptrauth")
    end
  {% end %}
end
