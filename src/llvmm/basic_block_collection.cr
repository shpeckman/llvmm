# src/llvmm/basic_block_collection.cr
require "./basic_block"

# The basic blocks of a `Function`, obtained via `Function#basic_blocks`.
#
# A lightweight view: the function owns its blocks, and this struct only
# holds a reference to it. Blocks are iterated in layout order.
#
# ```
# func.basic_blocks.append("entry") do |builder|
#   builder.ret builder.add(func.params[0], func.params[1])
# end
# ```
struct LLVMM::BasicBlockCollection
  include Enumerable(LLVMM::BasicBlock)

  def initialize(@function : Function)
  end

  # Appends a new basic block named *name* to the end of the function and
  # returns it. The block is created in the context of the function's module.
  def append(name = "")
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    BasicBlock.new LibLLVMM.append_basic_block_in_context(context, @function, name)
  end

  # Appends a new basic block and yields a `Builder` positioned at its end.
  # Returns the new block. The builder is disposed by the GC finalizer; it
  # must not be used after the block returns.
  def append(name = "", &)
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    block   = append name
    # builder = Builder.new(LibLLVMM.create_builder_in_context(context), LLVMM::Context.new(context, dispose_on_finalize: false))
    builder = Builder.new(LibLLVMM.create_builder_in_context(context))
    builder.position_at_end block
    yield builder
    block
  end

  # Appends an existing (e.g. previously detached) basic block to the end of
  # the function and returns it.
  def append_existing(block : BasicBlock) : BasicBlock
    LibLLVMM.append_existing_basic_block(@function, block)
    block
  end

  # Inserts a new basic block named *name* immediately before *block* and
  # returns it. The block is created in the context of the function's module.
  def insert_before(block : BasicBlock, name = "") : BasicBlock
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    BasicBlock.new LibLLVMM.insert_basic_block_in_context(context, block, name)
  end

  # The number of basic blocks in the function.
  def size : Int32
    LibLLVMM.count_basic_blocks(@function).to_i32
  end

  # Iterates the function's basic blocks in layout order.
  def each(&) : Nil
    bb = LibLLVMM.get_first_basic_block(@function)
    while bb
      yield LLVMM::BasicBlock.new bb
      bb = LibLLVMM.get_next_basic_block(bb)
    end
  end

  # The first basic block named *name*, or `nil` if there is none.
  def []?(name : String)
    find(&.name.==(name))
  end

  # The first basic block named *name*. Raises `IndexError` if there is none.
  def [](name : String)
    self[name]? || raise IndexError.new
  end

  # The last basic block of the function, or `nil` if it has none.
  def last?
    block = nil
    each do |current_block|
      block = current_block
    end
    block
  end
end
