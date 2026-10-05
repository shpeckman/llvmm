# src/llvmm/object.cr
# A binary object file opened for reading sections, symbols and
# relocations (wraps `LLVMBinaryRef`).
#
# Created with `.create`, which takes ownership of the source
# `MemoryBuffer`. Disposed by `#dispose` or by the GC finalizer; disposal
# is idempotent.
class LLVMM::ObjectFile
  # Creates an object file from *mem_buf*, taking ownership of the buffer.
  #
  # Raises if the buffer's ownership was already taken or its contents are
  # not a recognized binary format.
  def self.create(mem_buf : LLVMM::MemoryBuffer) : self
    mem_buf.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    binary = LibLLVMM.create_binary(mem_buf, nil, out msg)
    raise LLVMM.string_and_dispose(msg) unless binary
    new(binary)
  end

  # Wraps the given raw reference, taking ownership of it.
  def initialize(@unwrap : LibLLVMM::BinaryRef)
    @finalized = false
  end

  # Yields every section of the object file.
  def each_section(& : Section ->) : Nil
    iter = LibLLVMM.object_file_copy_section_iterator(self)
    begin
      until LibLLVMM.object_file_is_section_iterator_at_end(self, iter) != 0
        yield Section.new(iter)
        LibLLVMM.move_to_next_section(iter)
      end
    ensure
      LibLLVMM.dispose_section_iterator(iter)
    end
  end

  # Yields every symbol of the object file.
  def each_symbol(& : ObjSymbol ->) : Nil
    iter = LibLLVMM.object_file_copy_symbol_iterator(self)
    begin
      until LibLLVMM.object_file_is_symbol_iterator_at_end(self, iter) != 0
        yield ObjSymbol.new(
          name: String.new(LibLLVMM.get_symbol_name(iter)),
          address: LibLLVMM.get_symbol_address(iter),
          size: LibLLVMM.get_symbol_size(iter))
        LibLLVMM.move_to_next_symbol(iter)
      end
    ensure
      LibLLVMM.dispose_symbol_iterator(iter)
    end
  end

  # Disposes the underlying binary; safe to call more than once. Also
  # called by the GC finalizer.
  def dispose : Nil
    return if @finalized
    @finalized = true
    LibLLVMM.dispose_binary(@unwrap)
  end

  def finalize
    dispose
  end

  def to_unsafe
    @unwrap
  end

  # A section of an `ObjectFile`.
  #
  # `contents` is a view into the binary's own memory and is only valid
  # while the owning `ObjectFile` is alive. `name` is empty for unnamed
  # sections.
  class Section
    getter name : String
    getter address : UInt64
    getter size : UInt64
    getter contents : Bytes

    # :nodoc:
    def initialize(iter : LibLLVMM::SectionIteratorRef)
      @iter = iter
      name_ptr = LibLLVMM.get_section_name(iter)
      @name = name_ptr ? String.new(name_ptr) : ""
      @address = LibLLVMM.get_section_address(iter)
      @size = LibLLVMM.get_section_size(iter)
      @contents = Slice.new(LibLLVMM.get_section_contents(iter).as(UInt8*), @size)
    end

    # Yields every relocation of this section.
    def each_relocation(& : Relocation ->) : Nil
      iter = LibLLVMM.get_relocations(@iter)
      begin
        until LibLLVMM.is_relocation_iterator_at_end(@iter, iter) != 0
          symbol_iter = LibLLVMM.get_relocation_symbol(iter)
          symbol_name = String.new(LibLLVMM.get_symbol_name(symbol_iter))
          LibLLVMM.dispose_symbol_iterator(symbol_iter)
          yield Relocation.new(
            offset: LibLLVMM.get_relocation_offset(iter),
            type: LibLLVMM.get_relocation_type(iter),
            type_name: LLVMM.string_and_dispose(LibLLVMM.get_relocation_type_name(iter)),
            value: LLVMM.string_and_dispose(LibLLVMM.get_relocation_value_string(iter)),
            symbol: symbol_name)
          LibLLVMM.move_to_next_relocation(iter)
        end
      ensure
        LibLLVMM.dispose_relocation_iterator(iter)
      end
    end
  end

  # A symbol of an `ObjectFile`.
  record ObjSymbol, name : String, address : UInt64, size : UInt64

  # A relocation entry of a `Section`: its byte *offset* in the section,
  # the numeric *type* with its textual *type_name*, a human-readable
  # *value* string, and the *symbol* it refers to.
  record Relocation, offset : UInt64, type : UInt64, type_name : String, value : String, symbol : String
end
