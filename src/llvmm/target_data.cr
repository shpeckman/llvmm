# src/llvmm/target_data.cr
# Data layout of a target: type sizes, alignments and struct member
# offsets (wraps `LLVMTargetDataRef`).
#
# Instances are obtained from `TargetMachine#data_layout`. The underlying
# reference is never disposed by this wrapper.
struct LLVMM::TargetData
  # Wraps the given raw reference without taking ownership.
  def initialize(@unwrap : LibLLVMM::TargetDataRef)
  end

  # Store size of *type* in bits.
  def size_in_bits(type)
    LibLLVMM.size_of_type_in_bits(self, type)
  end

  # Store size of *type* in bytes, rounding non-byte-multiple bit sizes up.
  def size_in_bytes(type)
    size_in_bits = size_in_bits(type)
    size_in_bits // 8 &+ (size_in_bits & 0x7 != 0 ? 1 : 0)
  end

  # ABI size of *type* in bytes, including alignment padding.
  def abi_size(type)
    LibLLVMM.abi_size_of_type(self, type)
  end

  # Required ABI alignment of *type* in bytes.
  def abi_alignment(type)
    LibLLVMM.abi_alignment_of_type(self, type)
  end

  def to_unsafe
    @unwrap
  end

  # Byte offset of the element at index *element* within *struct_type*.
  def offset_of_element(struct_type, element)
    # element_count = LibLLVMM.count_struct_element_types(struct_type)
    # raise "Invalid element idx!" unless element < element_count
    LibLLVMM.offset_of_element(self, struct_type, element)
  end

  # Returns the textual data layout string.
  def to_data_layout_string
    LLVMM.string_and_dispose(LibLLVMM.copy_string_rep_of_target_data(self))
  end
end
