# src/llvmm/phi_table.cr
struct LLVMM::PhiTable
  getter blocks : Array(LLVMM::BasicBlock)
  getter values : Array(LLVMM::Value)

  def initialize
    @blocks = [] of LLVMM::BasicBlock
    @values = [] of LLVMM::Value
  end

  def add(block, value)
    @blocks << block
    @values << value.to_value
  end

  def empty?
    @blocks.empty?
  end

  def size
    @blocks.size
  end
end
