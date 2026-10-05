# src/llvmm/parameter_collection.cr
# The parameters of a `Function`, obtained via `Function#params`.
#
# A lightweight view: the function owns its parameters, and this struct only
# holds a reference to it. Each parameter is exposed as a `Value`, indexable
# by position.
struct LLVMM::ParameterCollection
  include Indexable(LLVMM::Value)

  def initialize(@function : Function)
  end

  # The number of parameters of the function.
  def size
    LibLLVMM.get_count_params(@function).to_i
  end

  # All parameters, in declaration order.
  def to_a : Array(LLVMM::Value)
    param_size = size()
    Array(LLVMM::Value).build(param_size) do |buffer|
      LibLLVMM.get_params(@function, buffer.as(LibLLVMM::ValueRef*))
      param_size
    end
  end

  # The parameter at *index*, without a bounds check. `Indexable#[]` performs
  # the check and raises `IndexError` for out-of-range indices.
  def unsafe_fetch(index : Int)
    Value.new LibLLVMM.get_param(@function, index)
  end

  # The types of all parameters, in declaration order.
  def types
    to_a.map(&.type)
  end
end
