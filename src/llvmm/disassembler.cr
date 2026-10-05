# src/llvmm/disassembler.cr
# Disassembles machine code into textual instructions for a target
# (wraps LLVM's disassembler, `LLVMDisasmContextRef`).
#
# The target for the triple must have been initialized first (see
# `LLVMM.init_native_target` / `LLVMM.init_all_targets`), otherwise
# creation raises. Call `#dispose` when finished, or rely on the GC
# finalizer; disposal is idempotent.
#
# ```
# disasm = LLVMM::Disassembler.new(LLVMM.default_target_triple, cpu: LLVMM.host_cpu_name)
# disasm.disassemble(Bytes[0xC3_u8]).each { |insn| puts insn.text }
# ```
class LLVMM::Disassembler
  # Flags controlling the disassembly output; combine with `|`.
  @[Flags]
  enum Option : UInt64
    # Emit markup annotations in the output.
    UseMarkup = 1
    # Print immediate operands in hexadecimal.
    PrintImmHex = 2
    # Use the assembly-printer variant of the instruction printer.
    AsmPrinterVariant = 4
    # Print instruction comments.
    SetInstrComments = 8
    # Print instruction latencies alongside the disassembly.
    PrintLatency = 16
    # Colorize the output with ANSI escapes.
    Color = 32
  end

  # A single disassembled instruction: its byte *offset* and *size* within
  # the input buffer, and its assembly *text*.
  record Instruction, offset : UInt64, size : UInt64, text : String

  getter triple : String

  # Creates a disassembler for *triple*, optionally specialized for *cpu*
  # and *features*. *features* is only used when *cpu* is also given.
  #
  # Raises if no disassembler can be created — typically because the
  # target for *triple* has not been initialized or the triple is invalid.
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

  # Applies output *options* (see `Option`).
  #
  # Raises if LLVM rejects the flags, e.g. because the linked LLVM version
  # does not support one of them.
  def options=(options : Option) : Option
    raise "Failed to set disassembler options #{options}" if LibLLVMM.set_disasm_options(self, options.value) == 0
    options
  end

  # Disassembles *bytes* into an array of `Instruction`, treating *pc* as
  # the address of the first byte.
  #
  # Stops at the first byte sequence LLVM cannot decode; any trailing
  # undecodable bytes are silently skipped.
  def disassemble(bytes : Bytes, pc : UInt64 = 0) : Array(Instruction)
    instructions = [] of Instruction
    disassemble(bytes, pc) { |instruction| instructions << instruction }
    instructions
  end

  # Yields each `Instruction` decoded from *bytes*, treating *pc* as the
  # address of the first byte.
  #
  # Stops at the first byte sequence LLVM cannot decode; any trailing
  # undecodable bytes are silently skipped.
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

  # Disposes the underlying disassembler; safe to call more than once.
  # Also called by the GC finalizer.
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
