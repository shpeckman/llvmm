# src/llvmm/named_metadata_collection.cr
struct LLVMM::NamedMetadata
  def initialize(@unwrap : LibLLVMM::NamedMDNodeRef)
  end

  def name : String
    ptr = LibLLVMM.get_named_metadata_name(self, out len)
    String.new(ptr, len)
  end

  def next : NamedMetadata?
    nmd = LibLLVMM.get_next_named_metadata(self)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  def previous : NamedMetadata?
    nmd = LibLLVMM.get_previous_named_metadata(self)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def to_unsafe
    @unwrap
  end
end

struct LLVMM::NamedMetadataCollection
  def initialize(@mod : Module)
  end

  def []?(name : String) : NamedMetadata?
    nmd = LibLLVMM.get_named_metadata(@mod, name, name.bytesize)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  def [](name : String) : NamedMetadata
    self[name]? || raise "Named metadata not found: #{name}"
  end

  def get_or_insert(name : String) : NamedMetadata
    NamedMetadata.new LibLLVMM.get_or_insert_named_metadata(@mod, name, name.bytesize)
  end

  def first : NamedMetadata?
    nmd = LibLLVMM.get_first_named_metadata(@mod)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  def last : NamedMetadata?
    nmd = LibLLVMM.get_last_named_metadata(@mod)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  def each(& : NamedMetadata ->) : Nil
    nmd = LibLLVMM.get_first_named_metadata(@mod)
    until nmd.null?
      yield NamedMetadata.new(nmd)
      nmd = LibLLVMM.get_next_named_metadata(nmd)
    end
  end

  def add_operand(name : String, value : Value)
    LibLLVMM.add_named_metadata_operand(@mod, name, value)
  end

  def num_operands(name : String) : Int32
    LibLLVMM.get_named_metadata_num_operands(@mod, name).to_i
  end

  def operands(name : String) : Array(Value)
    count = LibLLVMM.get_named_metadata_num_operands(@mod, name)
    return [] of Value if count == 0
    ptr = Pointer(LibLLVMM::ValueRef).malloc(count)
    LibLLVMM.get_named_metadata_operands(@mod, name, ptr)
    Array.new(count) { |i| Value.new(ptr[i]) }
  end
end
