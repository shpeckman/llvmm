# src/llvmm/memory_buffer.cr
# A memory region passed to or received from LLVM (wraps
# `LLVMMemoryBufferRef`) — for example bitcode for `Module.parse` or
# machine code emitted by `TargetMachine`.
#
# Unless ownership is transferred with `#take_ownership` (as
# `ObjectFile.create` does), the GC finalizer disposes the buffer.
class LLVMM::MemoryBuffer
  # Creates a buffer holding the contents of the file at *filename*.
  #
  # Raises with LLVM's error message if the file cannot be read.
  def self.from_file(filename : String)
    ret = LibLLVMM.create_memory_buffer_with_contents_of_file(filename, out mem_buf, out msg)
    if ret != 0 && msg
      raise LLVMM.string_and_dispose(msg)
    end
    new(mem_buf)
  end

  # Wraps the given raw reference, taking ownership of it.
  def initialize(@unwrap : LibLLVMM::MemoryBufferRef)
    @finalized = false
    @owned = false
  end

  # Creates a buffer referencing *slice* without copying. The slice must
  # remain valid for the whole lifetime of the buffer and of everything
  # that consumes it.
  def self.create(slice : Bytes, name : String = "") : self
    new(LibLLVMM.create_memory_buffer_with_memory_range(slice.to_unsafe.as(LibLLVMM::Char*), slice.size, name, false))
  end

  # Creates a buffer owning a private copy of *slice*'s contents.
  def self.create_copy(slice : Bytes, name : String = "") : self
    new(LibLLVMM.create_memory_buffer_with_memory_range_copy(slice.to_unsafe.as(LibLLVMM::Char*), slice.size, name))
  end

  # Marks the underlying buffer as owned by an external consumer, so the
  # finalizer no longer disposes it.
  #
  # Yields only when ownership has already been taken; consumers pass a
  # block that raises in that case.
  def take_ownership(&) : Nil
    if @owned
      yield
    else
      @owned = true
    end
  end

  # Returns the buffer's contents as a `Bytes` view into the buffer's own
  # memory; valid only while the buffer is alive and undisposed.
  def to_slice
    Slice.new(
      LibLLVMM.get_buffer_start(@unwrap),
      LibLLVMM.get_buffer_size(@unwrap),
    )
  end

  # Marks this wrapper as finalized so the GC finalizer leaves the
  # underlying buffer alone.
  #
  # NOTE: this does not free the buffer itself; transfer ownership with
  # `#take_ownership` to hand it to a consumer that frees it.
  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  # Disposes the buffer unless ownership was taken or the wrapper was
  # already finalized. Called by the GC.
  def finalize
    return if @finalized
    return if @owned

    LibLLVMM.dispose_memory_buffer(@unwrap)
  end

  def to_unsafe
    @unwrap
  end
end
