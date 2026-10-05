# src/llvmm/basic_block.cr
struct LLVMM::BasicBlock
  def initialize(@unwrap : LibLLVMM::BasicBlockRef)
  end

  def self.null
    LLVMM::BasicBlock.new(Pointer(::Void).null.as(LibLLVMM::BasicBlockRef))
  end

  def instructions
    InstructionCollection.new self
  end

  def delete
    LibLLVMM.delete_basic_block self
  end

  def to_unsafe
    @unwrap
  end

  def name
    block_name = LibLLVMM.get_basic_block_name(self)
    block_name ? String.new(block_name) : nil
  end

  def parent : Function?
    parent_func = LibLLVMM.get_basic_block_parent(self)
    parent_func ? Function.new(parent_func) : nil
  end

  def block_address
    Value.new LibLLVMM.block_address(LibLLVMM.get_basic_block_parent(self), self)
  end

  def move_before(other : BasicBlock)
    LibLLVMM.move_basic_block_before(self, other)
  end

  def move_after(other : BasicBlock)
    LibLLVMM.move_basic_block_after(self, other)
  end

  def remove_from_parent
    LibLLVMM.remove_basic_block_from_parent(self)
  end

  def to_value : Value
    Value.new LibLLVMM.basic_block_as_value(self)
  end
end
