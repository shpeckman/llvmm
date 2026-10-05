# src/llvmm/phi_table.cr

# Collects incoming (block, value) pairs for building a phi node.
#
# A pure Crystal helper with no LLVM resources: fill it with `#add` and
# pass it to `Builder#phi`, which appends all pairs as incoming edges of
# the phi node.
#
# ```
# table = LLVMM::PhiTable.new
# table.add(then_block, then_value)
# table.add(else_block, else_value)
# result = builder.phi(context.int32, table, "result")
# ```
struct LLVMM::PhiTable
  getter blocks : Array(LLVMM::BasicBlock)
  getter values : Array(LLVMM::Value)

  def initialize
    @blocks = [] of LLVMM::BasicBlock
    @values = [] of LLVMM::Value
  end

  # Adds an incoming pair: *value* arrives from predecessor *block*.
  # *value* may be anything responding to `#to_value`. Blocks and values
  # are added pairwise, so both arrays always have the same size.
  def add(block, value)
    @blocks << block
    @values << value.to_value
  end

  # Whether no incoming pairs have been added.
  def empty?
    @blocks.empty?
  end

  # The number of incoming pairs.
  def size
    @blocks.size
  end
end
