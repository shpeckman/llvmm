# src/llvmm/function.cr
require "./value_methods"

struct LLVMM::Function
  include LLVMM::ValueMethods

  def self.from_value(value : LLVMM::ValueMethods)
    new(value.to_unsafe)
  end

  def function_type : Type
    Type.new LibLLVMM.global_get_value_type(self)
  end

  def basic_blocks
    BasicBlockCollection.new self
  end

  def call_convention
    LLVMM::CallConvention.new LibLLVMM.get_function_call_convention(self)
  end

  def call_convention=(cc)
    LibLLVMM.set_function_call_convention(self, cc)
  end

  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex, type : Type? = nil)
    return if attribute.value == 0

    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute.each_kind do |kind|
      LibLLVMM.add_attribute_at_index(self, index, attribute_ref(context, kind, type))
    end
  end

  def add_attribute(attribute : String, index = AttributeIndex::FunctionIndex, *, value : String)
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute_ref = LibLLVMM.create_string_attribute(context, attribute, attribute.bytesize,
      value, value.bytesize)
    LibLLVMM.add_attribute_at_index(self, index, attribute_ref)
  end

  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex, *, value)
    return if attribute.value == 0

    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute.each_kind do |kind|
      attribute_ref = LibLLVMM.create_enum_attribute(context, kind, value.to_u64)
      LibLLVMM.add_attribute_at_index(self, index, attribute_ref)
    end
  end

  def add_target_dependent_attribute(name, value)
    LibLLVMM.add_target_dependent_function_attr self, name, value
  end

  def attributes(index = AttributeIndex::FunctionIndex)
    attrs = Attribute::None
    0.upto(LibLLVMM.get_last_enum_attribute_kind) do |kind|
      if LibLLVMM.get_enum_attribute_at_index(self, index, kind)
        attrs |= Attribute.from_kind(kind)
      end
    end
    attrs
  end

  def params
    ParameterCollection.new self
  end

  def personality_function=(fn)
    LibLLVMM.set_personality_fn(self, fn)
  end

  def delete
    LibLLVMM.delete_function(self)
  end

  def naked?
    attributes.naked?
  end
end
