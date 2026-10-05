# src/llvmm/value.cr
require "./value_methods"

struct LLVMM::Value
  include ValueMethods

  def self.null
    LLVMM::Value.new(Pointer(::Void).null.as(LibLLVMM::ValueRef))
  end

  def to_value
    self
  end

  def basic_block? : Bool
    LibLLVMM.value_is_basic_block(self) != 0
  end

  def to_basic_block : BasicBlock
    BasicBlock.new LibLLVMM.value_as_basic_block(self)
  end

  def const_gep(type : Type, indices : Array(Value)) : Value
    Value.new LibLLVMM.const_gep2(type, self, (indices.to_unsafe.as(LibLLVMM::ValueRef*)), indices.size)
  end

  def const_in_bounds_gep(type : Type, indices : Array(Value)) : Value
    Value.new LibLLVMM.const_in_bounds_gep2(type, self, (indices.to_unsafe.as(LibLLVMM::ValueRef*)), indices.size)
  end

  def const_extract_element(index : Value) : Value
    Value.new LibLLVMM.const_extract_element(self, index)
  end

  def const_insert_element(element : Value, index : Value) : Value
    Value.new LibLLVMM.const_insert_element(self, element, index)
  end

  def const_shuffle_vector(other : Value, mask : Value) : Value
    Value.new LibLLVMM.const_shuffle_vector(self, other, mask)
  end

  def const_real_get_double : {Float64, Bool}
    value = LibLLVMM.const_real_get_double(self, out loses_info)
    {value, loses_info != 0}
  end
end
