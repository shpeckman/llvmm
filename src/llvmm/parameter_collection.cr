# src/llvmm/parameter_collection.cr
struct LLVMM::ParameterCollection
  include Indexable(LLVMM::Value)

  def initialize(@function : Function)
  end

  def size
    LibLLVMM.get_count_params(@function).to_i
  end

  def to_a : Array(LLVMM::Value)
    param_size = size()
    Array(LLVMM::Value).build(param_size) do |buffer|
      LibLLVMM.get_params(@function, buffer.as(LibLLVMM::ValueRef*))
      param_size
    end
  end

  def unsafe_fetch(index : Int)
    Value.new LibLLVMM.get_param(@function, index)
  end

  def types
    to_a.map(&.type)
  end
end
