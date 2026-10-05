# src/llvmm/disassembler.cr
class LLVMM::Disassembler
  @[Flags]
  enum Option : UInt64
    UseMarkup         =  1
    PrintImmHex       =  2
    AsmPrinterVariant =  4
    SetInstrComments  =  8
    PrintLatency      = 16
    Color             = 32
  end

  record Instruction, offset : UInt64, size : UInt64, text : String

  getter triple : String

  def initialize(@triple : String, cpu : String? = nil, features : String? = nil)
    @unwrap =
      if cpu && features
        LibLLVMM.create_disasm_cpu_features(triple, cpu, features, nil, 0, nil, nil)
      elsif cpu
        LibLLVMM.create_disasm_cpu(triple, cpu, nil, 0, nil, nil)
      else
        LibLLVMM.create_disasm(triple, nil, 0, nil, nil)
      end
    unless @unwrap
      raise "Failed to create disassembler for triple '#{triple}' (target initialized? call LLVMM.init_native_target or LLVMM.init_all_targets first)"
    end
    @finalized = false
  end

  def options=(options : Option) : Option
    raise "Failed to set disassembler options #{options}" if LibLLVMM.set_disasm_options(self, options.value) == 0
    options
  end

  def disassemble(bytes : Bytes, pc : UInt64 = 0) : Array(Instruction)
    instructions = [] of Instruction
    disassemble(bytes, pc) { |instruction| instructions << instruction }
    instructions
  end

  def disassemble(bytes : Bytes, pc : UInt64 = 0, & : Instruction ->) : Nil
    buffer = uninitialized UInt8[256]
    offset = 0_u64
    while offset < bytes.size
      size = LibLLVMM.disasm_instruction(self, bytes.to_unsafe + offset, bytes.size.to_u64 - offset, pc + offset, buffer.to_unsafe.as(LibLLVMM::Char*), buffer.size)
      break if size == 0
      yield Instruction.new(offset: offset, size: size.to_u64, text: String.new(buffer.to_unsafe.as(LibLLVMM::Char*)))
      offset += size
    end
  end

  def dispose : Nil
    return if @finalized
    @finalized = true
    LibLLVMM.disasm_dispose(@unwrap)
  end

  def finalize
    dispose
  end

  def to_unsafe
    @unwrap
  end
end
