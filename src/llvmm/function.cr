# src/llvmm/function.cr
require "./value_methods"

# A function in an LLVM module, wrapping an `LLVMValueRef` of function type.
#
# A `Function` is owned by the `Module` it was created in (typically via
# `Module#functions.add`) and stays valid for the module's lifetime; it is
# not disposed individually. Use `#delete` to remove it from its module.
#
# ```
# func = mod.functions.add("add", [context.int32, context.int32], context.int32)
# func.basic_blocks.append("entry") do |builder|
#   builder.ret builder.add(func.params[0], func.params[1])
# end
# ```
struct LLVMM::Function
  include LLVMM::ValueMethods

  # Casts any value known to be a function to `Function`.
  def self.from_value(value : LLVMM::ValueMethods)
    new(value.to_unsafe)
  end

  # The function's type, including its return type and parameter types.
  def function_type : Type
    Type.new LibLLVMM.global_get_value_type(self)
  end

  # The function's basic blocks.
  def basic_blocks
    BasicBlockCollection.new self
  end

  # The function's calling convention.
  def call_convention
    LLVMM::CallConvention.new LibLLVMM.get_function_call_convention(self)
  end

  # Sets the function's calling convention.
  def call_convention=(cc)
    LibLLVMM.set_function_call_convention(self, cc)
  end

  # Adds enum attribute(s) at *index* (`AttributeIndex::FunctionIndex` for
  # the function itself, `AttributeIndex::ReturnIndex` for the return value,
  # or a 1-based parameter index). *attribute* may combine several
  # `Attribute` flags; each is added separately. *type* is only needed for
  # type-bearing attributes such as `Attribute::ByVal`. Passing
  # `Attribute::None` is a no-op.
  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex, type : Type? = nil)
    return if attribute.value == 0

    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute.each_kind do |kind|
      LibLLVMM.add_attribute_at_index(self, index, attribute_ref(context, kind, type))
    end
  end

  # Adds a string attribute with the given *attribute* name and *value*
  # at *index*.
  def add_attribute(attribute : String, index = AttributeIndex::FunctionIndex, *, value : String)
    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute_ref = LibLLVMM.create_string_attribute(context, attribute, attribute.bytesize,
      value, value.bytesize)
    LibLLVMM.add_attribute_at_index(self, index, attribute_ref)
  end

  # Adds enum attribute(s) with a numeric *value* at *index*, for
  # value-bearing attributes such as `Attribute::Alignment`. Passing
  # `Attribute::None` is a no-op.
  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex, *, value)
    return if attribute.value == 0

    context = LibLLVMM.get_module_context(LibLLVMM.get_global_parent(self))
    attribute.each_kind do |kind|
      attribute_ref = LibLLVMM.create_enum_attribute(context, kind, value.to_u64)
      LibLLVMM.add_attribute_at_index(self, index, attribute_ref)
    end
  end

  # Adds a target-specific function attribute (e.g. a target CPU feature)
  # as a name/value pair.
  def add_target_dependent_attribute(name, value)
    LibLLVMM.add_target_dependent_function_attr self, name, value
  end

  # The enum attributes set at *index*, combined into a single
  # `Attribute` flags value. String attributes are not included.
  def attributes(index = AttributeIndex::FunctionIndex)
    attrs = Attribute::None
    0.upto(LibLLVMM.get_last_enum_attribute_kind) do |kind|
      if LibLLVMM.get_enum_attribute_at_index(self, index, kind)
        attrs |= Attribute.from_kind(kind)
      end
    end
    attrs
  end

  # The function's parameters.
  def params
    ParameterCollection.new self
  end

  # Sets the personality function used by this function's exception
  # handling (e.g. for `invoke`/`landingpad`).
  def personality_function=(fn)
    LibLLVMM.set_personality_fn(self, fn)
  end

  # Removes the function from its parent module and deletes it. The
  # function must not be used afterwards.
  def delete
    LibLLVMM.delete_function(self)
  end

  # Whether the function carries the `Attribute::Naked` attribute.
  def naked?
    attributes.naked?
  end
end
