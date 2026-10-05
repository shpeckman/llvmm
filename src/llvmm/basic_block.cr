# src/llvmm/basic_block.cr

# A basic block in a function, wrapping LLVM's `LLVMBasicBlockRef`.
#
# A `BasicBlock` is owned by its parent `Function` (usually created via
# `Function#basic_blocks.append`) and stays valid while attached to it.
# `#delete` destroys the block; `#remove_from_parent` detaches it without
# destroying it.
struct LLVMM::BasicBlock
  def initialize(@unwrap : LibLLVMM::BasicBlockRef)
  end

  # A basic block wrapping a null reference.
  def self.null
    LLVMM::BasicBlock.new(Pointer(::Void).null.as(LibLLVMM::BasicBlockRef))
  end

  # The block's instructions.
  def instructions
    InstructionCollection.new self
  end

  # Removes the block from its parent function and deletes it. The block
  # must not be used afterwards. See `#remove_from_parent` for detaching
  # without deleting.
  def delete
    LibLLVMM.delete_basic_block self
  end

  def to_unsafe
    @unwrap
  end

  # The block's name, or `nil` for an unnamed block.
  def name
    block_name = LibLLVMM.get_basic_block_name(self)
    block_name ? String.new(block_name) : nil
  end

  # The function this block belongs to, or `nil` if the block has been
  # removed from its parent with `#remove_from_parent`.
  def parent : Function?
    parent_func = LibLLVMM.get_basic_block_parent(self)
    parent_func ? Function.new(parent_func) : nil
  end

  # The `blockaddress` constant for this block. The block must be attached
  # to a function.
  def block_address
    Value.new LibLLVMM.block_address(LibLLVMM.get_basic_block_parent(self), self)
  end

  # Moves this block to just before *other* in the parent function.
  def move_before(other : BasicBlock)
    LibLLVMM.move_basic_block_before(self, other)
  end

  # Moves this block to just after *other* in the parent function.
  def move_after(other : BasicBlock)
    LibLLVMM.move_basic_block_after(self, other)
  end

  # Detaches the block from its parent function without deleting it. The
  # block remains valid and can be re-inserted or deleted later.
  def remove_from_parent
    LibLLVMM.remove_basic_block_from_parent(self)
  end

  # This block viewed as a `Value`.
  def to_value : Value
    Value.new LibLLVMM.basic_block_as_value(self)
  end
end
