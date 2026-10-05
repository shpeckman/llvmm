# src/llvmm/memory_buffer.cr
class LLVMM::MemoryBuffer
  def self.from_file(filename : String)
    ret = LibLLVMM.create_memory_buffer_with_contents_of_file(filename, out mem_buf, out msg)
    if ret != 0 && msg
      raise LLVMM.string_and_dispose(msg)
    end
    new(mem_buf)
  end

  def initialize(@unwrap : LibLLVMM::MemoryBufferRef)
    @finalized = false
    @owned     = false
  end

  def self.create(slice : Bytes, name : String = "") : self
    new(LibLLVMM.create_memory_buffer_with_memory_range(slice.to_unsafe.as(LibLLVMM::Char*), slice.size, name, false))
  end

  def self.create_copy(slice : Bytes, name : String = "") : self
    new(LibLLVMM.create_memory_buffer_with_memory_range_copy(slice.to_unsafe.as(LibLLVMM::Char*), slice.size, name))
  end

  def take_ownership(&) : Nil
    if @owned
      yield
    else
      @owned = true
    end
  end

  def to_slice
    Slice.new(
      LibLLVMM.get_buffer_start(@unwrap),
      LibLLVMM.get_buffer_size(@unwrap),
    )
  end

  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  def finalize
    return if @finalized
    return if @owned

    LibLLVMM.dispose_memory_buffer(@unwrap)
  end

  def to_unsafe
    @unwrap
  end
end
