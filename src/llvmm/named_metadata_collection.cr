# src/llvmm/named_metadata_collection.cr
# A named metadata node of a module (wraps LLVM's `NamedMDNode`), as returned
# by `NamedMetadataCollection`.
#
# The node is owned by its module; this struct only holds a reference.
struct LLVMM::NamedMetadata
  def initialize(@unwrap : LibLLVMM::NamedMDNodeRef)
  end

  def name : String
    ptr = LibLLVMM.get_named_metadata_name(self, out len)
    String.new(ptr, len)
  end

  # The next named metadata node in the module, or `nil` if this is the last.
  def next : NamedMetadata?
    nmd = LibLLVMM.get_next_named_metadata(self)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  # The previous named metadata node in the module, or `nil` if this is the
  # first.
  def previous : NamedMetadata?
    nmd = LibLLVMM.get_previous_named_metadata(self)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  # Two nodes are equal when they wrap the same underlying LLVM node.
  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def to_unsafe
    @unwrap
  end
end

# The named metadata of a `Module`, obtained via `Module#named_metadata`.
#
# A lightweight view: the module owns its named metadata nodes, and this
# struct only holds a reference to it.
struct LLVMM::NamedMetadataCollection
  def initialize(@mod : Module)
  end

  # The named metadata node named *name*, or `nil` if the module has none.
  def []?(name : String) : NamedMetadata?
    nmd = LibLLVMM.get_named_metadata(@mod, name, name.bytesize)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  # The named metadata node named *name*. Raises if the module has none.
  def [](name : String) : NamedMetadata
    self[name]? || raise "Named metadata not found: #{name}"
  end

  # The named metadata node named *name*, creating an empty one if the module
  # does not have it yet.
  def get_or_insert(name : String) : NamedMetadata
    NamedMetadata.new LibLLVMM.get_or_insert_named_metadata(@mod, name, name.bytesize)
  end

  # The first named metadata node of the module, or `nil` if it has none.
  def first : NamedMetadata?
    nmd = LibLLVMM.get_first_named_metadata(@mod)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  # The last named metadata node of the module, or `nil` if it has none.
  def last : NamedMetadata?
    nmd = LibLLVMM.get_last_named_metadata(@mod)
    nmd.null? ? nil : NamedMetadata.new(nmd)
  end

  # Iterates the module's named metadata nodes.
  #
  # NOTE: does not `include Enumerable`; only `each` is provided.
  def each(& : NamedMetadata ->) : Nil
    nmd = LibLLVMM.get_first_named_metadata(@mod)
    until nmd.null?
      yield NamedMetadata.new(nmd)
      nmd = LibLLVMM.get_next_named_metadata(nmd)
    end
  end

  # Appends *value* (typically a metadata node wrapped via
  # `LibLLVMM.metadata_as_value`) to the operands of the node named *name*.
  def add_operand(name : String, value : Value)
    LibLLVMM.add_named_metadata_operand(@mod, name, value)
  end

  # The number of operands of the node named *name*.
  def num_operands(name : String) : Int32
    LibLLVMM.get_named_metadata_num_operands(@mod, name).to_i
  end

  # The operands of the node named *name*. Returns an empty array when the
  # node has no operands.
  def operands(name : String) : Array(Value)
    count = LibLLVMM.get_named_metadata_num_operands(@mod, name)
    return [] of Value if count == 0
    ptr = Pointer(LibLLVMM::ValueRef).malloc(count)
    LibLLVMM.get_named_metadata_operands(@mod, name, ptr)
    Array.new(count) { |i| Value.new(ptr[i]) }
  end
end
