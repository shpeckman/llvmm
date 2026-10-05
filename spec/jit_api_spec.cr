# spec/jit_api_spec.cr
require "./spec_helper"

private record Point, x : Int32, y : Int32

describe LLVMM::JIT do
  it "calls functions with scalar signatures" do
    LLVMM::JIT.new do |jit|
      mod = jit.new_module("scal")
      add = mod.functions.add("add", [jit.context.int32, jit.context.int32], jit.context.int32)
      add.basic_blocks.append("entry") do |builder|
        builder.ret(builder.add(add.params[0], add.params[1]))
      end
      jit.add_module(mod)

      jit.function("add", Int32, Int32, Int32).call(19, 23).should eq(42)
    end
  end

  it "maps Int64, Float64, Bool, Nil, and pointers" do
    LLVMM::JIT.new do |jit|
      mod        = jit.new_module("breadth")
      int64_ty   = jit.context.int64
      float64_ty = jit.context.double

      classify = mod.functions.add("classify", [int64_ty], jit.context.int1)
      classify.basic_blocks.append("entry") do |builder|
        builder.ret(builder.icmp(LLVMM::IntPredicate::SGT, classify.params[0], int64_ty.const_int(0)))
      end

      scale = mod.functions.add("scale", [float64_ty], float64_ty)
      scale.basic_blocks.append("entry") do |builder|
        builder.ret(builder.fmul(scale.params[0], float64_ty.const_double(4.0)))
      end

      sink = mod.functions.add("sink", [jit.context.void_pointer, jit.context.int32], jit.context.void)
      sink.basic_blocks.append("entry") do |builder|
        builder.store(sink.params[1], sink.params[0])
        builder.ret
      end

      jit.add_module(mod)

      jit.function("classify", Int64, Bool).call(-5_i64).should eq(false)
      jit.function("classify", Int64, Bool).call(9_i64).should eq(true)
      jit.function("scale", Float64, Float64).call(1.5).should eq(6.0)

      ptr = Pointer(Int32).malloc(1)
      jit.function("sink", Pointer(Int32), Int32, Nil).call(ptr, 7).should be_nil
      ptr.value.should eq(7)
    end
  end

  it "passes StaticArray and structs by value" do
    LLVMM::JIT.new do |jit|
      mod      = jit.new_module("aggregates")
      int32_ty = jit.context.int32
      arr_ty   = int32_ty.array(4)
      point_ty = jit.context.struct([int32_ty, int32_ty])

      sum_arr = mod.functions.add("sum_arr", [arr_ty], int32_ty)
      sum_arr.basic_blocks.append("entry") do |builder|
        a = builder.extract_value(sum_arr.params[0], 0)
        b = builder.extract_value(sum_arr.params[0], 1)
        c = builder.extract_value(sum_arr.params[0], 2)
        d = builder.extract_value(sum_arr.params[0], 3)
        builder.ret(builder.add(builder.add(a, b), builder.add(c, d)))
      end

      sum_point = mod.functions.add("sum_point", [point_ty], int32_ty)
      sum_point.basic_blocks.append("entry") do |builder|
        x = builder.extract_value(sum_point.params[0], 0)
        y = builder.extract_value(sum_point.params[0], 1)
        builder.ret(builder.add(x, y))
      end

      jit.add_module(mod)

      values = StaticArray(Int32, 4).new { |i| i + 1 }
      jit.function("sum_arr", StaticArray(Int32, 4), Int32).call(values).should eq(10)
      jit.function("sum_point", Point, Int32).call(Point.new(19, 23)).should eq(42)
    end
  end

  it "raises on unknown names and signature mismatches" do
    LLVMM::JIT.new do |jit|
      mod = jit.new_module("errors")
      inc = mod.functions.add("inc", [jit.context.int32], jit.context.int32)
      inc.basic_blocks.append("entry") do |builder|
        builder.ret(builder.add(inc.params[0], jit.context.int32.const_int(1)))
      end
      jit.add_module(mod)

      expect_raises(Exception, "no function named 'missing'") do
        jit.function("missing", Int32)
      end
      expect_raises(Exception, "returns i32, not i64") do
        jit.function("inc", Int32, Int64)
      end
      expect_raises(Exception, "argument 0 is i32, not i64") do
        jit.function("inc", Int64, Int32)
      end
    end
  end

  it "calls process symbols from JIT'd code" do
    LLVMM::JIT.new do |jit|
      mod       = jit.new_module("proc_syms")
      int32_ty  = jit.context.int32
      abs_fn    = mod.functions.add("abs", [int32_ty], int32_ty)
      caller_fn = mod.functions.add("call_abs", [int32_ty], int32_ty)
      caller_fn.basic_blocks.append("entry") do |builder|
        result = builder.call(abs_fn.function_type, abs_fn, [caller_fn.params[0]], "absval")
        builder.ret result
      end
      jit.add_module(mod)
      jit.link_process_symbols

      jit.function("call_abs", Int32, Int32).call(-7).should eq(7)
    end
  end

  it "calls registered absolute symbols from JIT'd code" do
    LLVMM::JIT.new do |jit|
      mod       = jit.new_module("abs_syms")
      int32_ty  = jit.context.int32
      helper    = mod.functions.add("llvmm_spec_double_it", [int32_ty], int32_ty)
      caller_fn = mod.functions.add("via_helper", [int32_ty], int32_ty)
      caller_fn.basic_blocks.append("entry") do |builder|
        result = builder.call(helper.function_type, helper, [caller_fn.params[0]], "doubled")
        builder.ret result
      end
      jit.add_module(mod)
      address = Pointer(Void).new(->llvmm_spec_double_it(Int32).pointer.address)
      jit.define("llvmm_spec_double_it", address)

      jit.function("via_helper", Int32, Int32).call(21).should eq(42)
    end
  end

  it "survives many create/add/call/dispose cycles" do
    25.times do |i|
      LLVMM::JIT.new do |jit|
        mod      = jit.new_module("cycle_#{i}")
        int32_ty = jit.context.int32
        fn       = mod.functions.add("roundtrip", [int32_ty], int32_ty)
        fn.basic_blocks.append("entry") do |builder|
          builder.ret(builder.add(fn.params[0], int32_ty.const_int(1)))
        end
        jit.add_module(mod)
        jit.function("roundtrip", Int32, Int32).call(i).should eq(i + 1)
      end
    end
  end
end

fun llvmm_spec_double_it(x : Int32) : Int32
  x * 2
end
