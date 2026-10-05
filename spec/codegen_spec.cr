# spec/codegen_spec.cr
require "./spec_helper"

private def host_machine : LLVMM::TargetMachine
  triple = LLVMM.default_target_triple
  LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
end

describe "codegen and object introspection" do
  it "emits an object to memory and walks sections, symbols, and relocations" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("stub_source")
    int32_ty = context.int32
    answer   = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    answer.basic_blocks.append("entry") do |builder|
      builder.ret(int32_ty.const_int(42))
    end
    extern_fn = mod.functions.add("callee_fn", [int32_ty], int32_ty)
    caller    = mod.functions.add("caller", [int32_ty], int32_ty)
    caller.basic_blocks.append("entry") do |builder|
      result = builder.call(extern_fn.function_type, extern_fn, [caller.params[0]], "calltmp")
      builder.ret result
    end

    buffer = host_machine.emit_obj_to_memory_buffer(mod)
    buffer.to_slice.size.should be > 0

    object  = LLVMM::ObjectFile.create(LLVMM::MemoryBuffer.create_copy(buffer.to_slice, "roundtrip"))
    symbols = {} of String => UInt64
    object.each_symbol { |symbol| symbols[symbol.name] = symbol.size }
    symbols["answer"].should be > 0
    symbols["caller"].should be > 0
    symbols.has_key?("callee_fn").should be_true

    text_size   = 0_u64
    relocations = [] of LLVMM::ObjectFile::Relocation
    found_text  = false
    object.each_section do |section|
      if section.name == ".text"
        found_text = true
        text_size  = section.contents.size
      end
      section.each_relocation { |relocation| relocations << relocation }
    end
    found_text.should be_true
    text_size.should be >= (symbols["caller"] + symbols["answer"])

    relocations.should_not be_empty
    relocations.any? { |relocation| relocation.symbol == "callee_fn" }.should be_true
    relocations.first.type_name.should_not be_empty
  end

  it "disassembles extracted stub code bytes" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("stub_disasm")
    int32_ty = context.int32
    answer   = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    answer.basic_blocks.append("entry") { |builder| builder.ret(int32_ty.const_int(42)) }

    buffer = host_machine.emit_obj_to_memory_buffer(mod)
    object = LLVMM::ObjectFile.create(LLVMM::MemoryBuffer.create_copy(buffer.to_slice, "disasm"))

    symbols = {} of String => LLVMM::ObjectFile::ObjSymbol
    object.each_symbol { |symbol| symbols[symbol.name] = symbol }
    answer_symbol = symbols["answer"]

    code = Bytes.empty
    object.each_section do |section|
      next unless section.name == ".text"
      start = (answer_symbol.address - section.address).to_i
      code  = section.contents[start, answer_symbol.size.to_i]
    end
    code.size.should be > 0

    disassembler  = LLVMM::Disassembler.new(LLVMM.default_target_triple, cpu: LLVMM.host_cpu_name)
    instructions  = disassembler.disassemble(code)
    disasm_report = instructions.map(&.text).join('\n')

    instructions.should_not be_empty
    instructions.sum(&.size).should eq(code.size)
    disasm_report.should contain("ret")
    disasm_report.should match(/42|0x2a/)
  end

  it "round-trips bytes through MemoryBuffer.create and to_slice" do
    bytes = Bytes[1, 2, 3, 4, 5]
    LLVMM::MemoryBuffer.create(bytes, "slice").to_slice.to_a.should eq([1, 2, 3, 4, 5])
    LLVMM::MemoryBuffer.create_copy(bytes, "slice").to_slice.to_a.should eq([1, 2, 3, 4, 5])
  end

  it "disposes a MemoryBuffer explicitly and idempotently" do
    buffer = LLVMM::MemoryBuffer.create_copy(Bytes[1, 2, 3], "dispose")
    buffer.to_slice.to_a.should eq([1, 2, 3])
    buffer.dispose
    buffer.dispose
  end

  it "leaves an owned MemoryBuffer to its consumer" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("owned_buffer")
    int32_ty = context.int32
    answer   = mod.functions.add("answer", [] of LLVMM::Type, int32_ty)
    answer.basic_blocks.append("entry") { |builder| builder.ret(int32_ty.const_int(42)) }

    buffer = host_machine.emit_obj_to_memory_buffer(mod)
    object = LLVMM::ObjectFile.create(buffer)
    buffer.dispose

    symbols = [] of String
    object.each_symbol { |symbol| symbols << symbol.name }
    symbols.should contain("answer")

    object.dispose
    GC.collect
  end

  it "JITs builder memory ops" do
    LLVMM::JIT.new do |jit|
      mod      = jit.new_module("memops")
      void_ptr = jit.context.void_pointer
      int32_ty = jit.context.int32
      int8_ty  = jit.context.int8

      copy_fn = mod.functions.add("copy", [void_ptr, void_ptr, int32_ty], jit.context.void)
      copy_fn.basic_blocks.append("entry") do |builder|
        builder.mem_copy(copy_fn.params[0], 8_u32, copy_fn.params[1], 8_u32, copy_fn.params[2])
        builder.ret
      end

      set_fn = mod.functions.add("set_all", [void_ptr, int32_ty, int8_ty], jit.context.void)
      set_fn.basic_blocks.append("entry") do |builder|
        builder.mem_set(set_fn.params[0], set_fn.params[2], set_fn.params[1])
        builder.ret
      end

      jit.add_module(mod)

      src = Pointer(Int32).malloc(4) { |i| i + 1 }
      dst = Pointer(Int32).malloc(4)
      jit.function("copy", Pointer(Int32), Pointer(Int32), Int32, Nil).call(dst, src, 16).should be_nil
      4.times { |i| dst[i].should eq(i + 1) }

      buf = Pointer(UInt8).malloc(8)
      jit.function("set_all", Pointer(UInt8), Int32, UInt8, Nil).call(buf, 8, 0xAB_u8).should be_nil
      8.times { |i| buf[i].should eq(0xAB) }
    end
  end

  it "JITs vector element and shuffle ops on packed cells" do
    LLVMM::JIT.new do |jit|
      mod      = jit.new_module("vectors")
      int32_ty = jit.context.int32
      int8_ty  = jit.context.int8
      cell_ty  = int8_ty.vector(4)

      byte_at = mod.functions.add("byte_at", [int32_ty, int32_ty], int32_ty)
      byte_at.basic_blocks.append("entry") do |builder|
        vec  = builder.bit_cast(byte_at.params[0], cell_ty, "cell")
        byte = builder.extract_element(vec, byte_at.params[1], "byte")
        builder.ret(builder.zext(byte, int32_ty, "wide"))
      end

      swap = mod.functions.add("swap_bytes", [int32_ty], int32_ty)
      swap.basic_blocks.append("entry") do |builder|
        vec      = builder.bit_cast(swap.params[0], cell_ty, "cell")
        mask     = jit.context.const_vector([3, 2, 1, 0].map { |i| int32_ty.const_int(i) })
        shuffled = builder.shuffle_vector(vec, vec, mask, "shuffled")
        builder.ret(builder.bit_cast(shuffled, int32_ty, "packed"))
      end

      jit.add_module(mod)

      jit.function("byte_at", Int32, Int32, Int32).call(0xAABBCCDD.to_i32!, 0).should eq(0xDD)
      jit.function("byte_at", Int32, Int32, Int32).call(0xAABBCCDD.to_i32!, 3).should eq(0xAA)
      jit.function("swap_bytes", Int32, Int32).call(0x11223344).should eq(0x44332211)
    end
  end

  it "dispatches float operands to f-ops and rejects mismatches" do
    LLVMM::JIT.new do |jit|
      mod       = jit.new_module("float_add")
      double_ty = jit.context.double
      fn        = mod.functions.add("add", [double_ty, double_ty], double_ty)
      fn.basic_blocks.append("entry") do |builder|
        builder.ret(builder.add(fn.params[0], fn.params[1]))
      end
      jit.add_module(mod)
      jit.function("add", Float64, Float64, Float64).call(2.5, 4.0).should eq(6.5)
    end

    LLVMM::Context.new.tap do |context|
      mod = context.new_module("mismatch")
      fn  = mod.functions.add("f", [context.int32, context.double], context.double)
      fn.basic_blocks.append("entry") do |builder|
        expect_raises(Exception, "invalid operand types for 'add'") do
          builder.add(fn.params[0], fn.params[1])
        end
        builder.ret(fn.params[1])
      end
    end
  end

  it "inserts allocas at the beginning of a terminated block" do
    context  = LLVMM::Context.new
    mod      = context.new_module("entry_alloca")
    int32_ty = context.int32
    fn       = mod.functions.add("f", [] of LLVMM::Type, int32_ty)
    entry    = fn.basic_blocks.append("entry")
    body     = fn.basic_blocks.append("body")
    builder  = context.new_builder
    builder.position_at_end(entry)
    builder.br(body)
    builder.position_at_begin(entry)
    builder.alloca(int32_ty, "early")
    builder.position_at_end(body)
    builder.ret(int32_ty.const_int(0))
    mod.verify

    ir = mod.to_s
    ir.index("%early").not_nil!.should be < (ir.index("br label").not_nil!)
  end

  it "applies pass builder options" do
    LLVMM.init_native_target

    context  = LLVMM::Context.new
    mod      = context.new_module("opts")
    int32_ty = context.int32
    fn       = mod.functions.add("f", [int32_ty], int32_ty)
    fn.basic_blocks.append("entry") do |builder|
      doubled = builder.mul(fn.params[0], int32_ty.const_int(2))
      builder.ret(builder.add(doubled, int32_ty.const_int(0)))
    end
    unoptimized = mod.to_s

    LLVMM::PassBuilderOptions.new do |options|
      options.set_inliner_threshold(2)
      options.set_loop_vectorization(true)
      options.set_slp_vectorization(true)
      LLVMM.run_passes(mod, "default<O2>", host_machine, options)
    end

    mod.to_s.should_not eq(unoptimized)

    LLVMM::JITCompiler.new(mod) do |jit|
      run = Proc(Int32, Int32).new(jit.function_address("f"), Pointer(Void).null)
      run.call(21).should eq(42)
    end
  end
end
