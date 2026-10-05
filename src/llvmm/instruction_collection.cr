# src/llvmm/instruction_collection.cr
struct LLVMM::InstructionCollection
  include Enumerable(LLVMM::Value)

  def initialize(@basic_block : BasicBlock)
  end

  def empty?
    first?.nil?
  end

  def each(&) : Nil
    inst = LibLLVMM.get_first_instruction @basic_block

    while inst
      yield LLVMM::Value.new inst
      inst = LibLLVMM.get_next_instruction(inst)
    end
  end
end
