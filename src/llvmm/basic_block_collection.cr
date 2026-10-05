# src/llvmm/basic_block_collection.cr
require "./basic_block"

struct LLVMM::BasicBlockCollection
  include Enumerable(LLVMM::BasicBlock)

  def initialize(@function : Function)
  end

  def append(name = "")
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    BasicBlock.new LibLLVMM.append_basic_block_in_context(context, @function, name)
  end

  def append(name = "", &)
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    block   = append name
    # builder = Builder.new(LibLLVMM.create_builder_in_context(context), LLVMM::Context.new(context, dispose_on_finalize: false))
    builder = Builder.new(LibLLVMM.create_builder_in_context(context))
    builder.position_at_end block
    yield builder
    block
  end

  def append_existing(block : BasicBlock) : BasicBlock
    LibLLVMM.append_existing_basic_block(@function, block)
    block
  end

  def insert_before(block : BasicBlock, name = "") : BasicBlock
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(@function))
    BasicBlock.new LibLLVMM.insert_basic_block_in_context(context, block, name)
  end

  def size : Int32
    LibLLVMM.count_basic_blocks(@function).to_i32
  end

  def each(&) : Nil
    bb = LibLLVMM.get_first_basic_block(@function)
    while bb
      yield LLVMM::BasicBlock.new bb
      bb = LibLLVMM.get_next_basic_block(bb)
    end
  end

  def []?(name : String)
    find(&.name.==(name))
  end

  def [](name : String)
    self[name]? || raise IndexError.new
  end

  def last?
    block = nil
    each do |current_block|
      block = current_block
    end
    block
  end
end
