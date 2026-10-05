# spec/llvmm_spec.cr
require "./spec_helper"

describe LLVMM do
  it "reports the runtime LLVM version" do
    LLVMM.version.should match(/^\d+\.\d+\.\d+$/)
    LLVMM.version.should start_with(LibLLVMM::VERSION.split('+').first.split('-').first)
  end

  it "normalizes and reports target information" do
    LLVMM.default_target_triple.should_not be_empty
    LLVMM.host_cpu_name.should_not be_empty
    LLVMM.normalize_triple("x86_64-unknown-linux-gnu").should eq("x86_64-unknown-linux-gnu")
  end

  it "builds, JIT-compiles and runs a function" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    mod     = context.new_module("smoke")

    func = mod.functions.add("add", [context.int32, context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      builder.ret builder.add(func.params[0], func.params[1])
    end

    LLVMM::JITCompiler.new(mod) do |jit|
      address = jit.function_address("add")
      address.should_not eq(Pointer(Void).null)

      add = Proc(Int32, Int32, Int32).new(address, Pointer(Void).null)
      add.call(19, 23).should eq(42)
    end
  end

  it "runs a new-pass-manager pipeline and preserves semantics" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    mod     = context.new_module("passes")

    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      zero_product = builder.mul(func.params[0], context.int32.const_int(0))
      builder.ret builder.add(func.params[0], zero_product)
    end

    unoptimized = mod.to_s

    triple  = LLVMM.default_target_triple
    target  = LLVMM::Target.from_triple(triple)
    machine = target.create_target_machine(triple, LLVMM.host_cpu_name)

    LLVMM::PassBuilderOptions.new do |options|
      options.set_loop_unrolling(true)
      LLVMM.run_passes(mod, "default<O2>", machine, options)
    end

    optimized = mod.to_s
    optimized.should_not eq(unoptimized)

    LLVMM::JITCompiler.new(mod) do |jit|
      f = Proc(Int32, Int32).new(jit.function_address("f"), Pointer(Void).null)
      f.call(7).should eq(7)
      f.call(-5).should eq(-5)
    end
  end

  it "disposes a JIT compiler explicitly and idempotently" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    mod     = context.new_module("explicit_dispose")

    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      builder.ret func.params[0]
    end

    jit = LLVMM::JITCompiler.new(mod)
    jit.function_address("f").should_not eq(Pointer(Void).null)
    jit.dispose
    jit.dispose
  end

  it "raises on an invalid pass pipeline" do
    LLVMM.init_native_target

    context = LLVMM::Context.new
    mod     = context.new_module("bad_passes")

    func = mod.functions.add("f", [context.int32], context.int32)
    func.basic_blocks.append("entry") do |builder|
      builder.ret func.params[0]
    end

    triple  = LLVMM.default_target_triple
    machine = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)

    LLVMM::PassBuilderOptions.new do |options|
      expect_raises(Exception) do
        LLVMM.run_passes(mod, "not-a-real-pass", machine, options)
      end
    end
  end
end
