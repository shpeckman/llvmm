# src/llvmm/value.cr
require "./value_methods"

# An LLVM value: wraps `LibLLVMM::ValueRef`.
#
# Non-owning: values are owned by the `Module`/`Context` that created them
# and stay valid for that owner's lifetime; they need no disposal. A value
# can be a constant, an instruction, a function, a global variable, an
# alias, or a basic block handle.
#
# The bulk of the API lives in `ValueMethods`, which is shared with
# `Function`.
struct LLVMM::Value
  include ValueMethods

  # A `Value` wrapping a null `LibLLVMM::ValueRef`.
  #
  # Used as a sentinel where an LLVM API takes an optional value, e.g. the
  # parent pad of `Builder#catch_switch` or `Builder#cleanup_pad`.
  def self.null
    LLVMM::Value.new(Pointer(::Void).null.as(LibLLVMM::ValueRef))
  end

  def to_value
    self
  end

  # Whether this value actually is a `BasicBlock`.
  def basic_block? : Bool
    LibLLVMM.value_is_basic_block(self) != 0
  end

  # Reinterprets this value as a `BasicBlock`.
  #
  # Only valid when `basic_block?` is `true`.
  def to_basic_block : BasicBlock
    BasicBlock.new LibLLVMM.value_as_basic_block(self)
  end

  # A constant getelementptr expression on this value.
  #
  # Because pointers are opaque, the source element *type* must be given
  # explicitly.
  def const_gep(type : Type, indices : Array(Value)) : Value
    Value.new LibLLVMM.const_gep2(type, self, (indices.to_unsafe.as(LibLLVMM::ValueRef*)), indices.size)
  end

  # Same as `const_gep`, but marked `inbounds`.
  def const_in_bounds_gep(type : Type, indices : Array(Value)) : Value
    Value.new LibLLVMM.const_in_bounds_gep2(type, self, (indices.to_unsafe.as(LibLLVMM::ValueRef*)), indices.size)
  end

  # A constant expression extracting the element at *index* from this
  # vector constant.
  def const_extract_element(index : Value) : Value
    Value.new LibLLVMM.const_extract_element(self, index)
  end

  # A constant expression inserting *element* at *index* into this vector
  # constant.
  def const_insert_element(element : Value, index : Value) : Value
    Value.new LibLLVMM.const_insert_element(self, element, index)
  end

  # A constant expression shuffling this vector constant with *other*
  # according to *mask*.
  def const_shuffle_vector(other : Value, mask : Value) : Value
    Value.new LibLLVMM.const_shuffle_vector(self, other, mask)
  end

  # The value of this floating-point constant as a `Float64`, plus a flag
  # telling whether the conversion lost precision.
  def const_real_get_double : {Float64, Bool}
    value = LibLLVMM.const_real_get_double(self, out loses_info)
    {value, loses_info != 0}
  end
end
