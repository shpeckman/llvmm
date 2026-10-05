# src/llvmm/instruction_collection.cr
# The instructions of a `BasicBlock`, obtained via `BasicBlock#instructions`.
#
# A lightweight view: the basic block owns its instructions, and this struct
# only holds a reference to it. Each instruction is exposed as a `Value` and
# iterated in program order.
struct LLVMM::InstructionCollection
  include Enumerable(LLVMM::Value)

  def initialize(@basic_block : BasicBlock)
  end

  # Whether the basic block contains no instructions.
  def empty?
    first?.nil?
  end

  # Iterates the block's instructions in program order.
  def each(&) : Nil
    inst = LibLLVMM.get_first_instruction @basic_block

    while inst
      yield LLVMM::Value.new inst
      inst = LibLLVMM.get_next_instruction(inst)
    end
  end
end
