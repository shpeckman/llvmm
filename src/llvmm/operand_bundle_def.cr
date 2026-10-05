# src/llvmm/operand_bundle_def.cr
struct LLVMM::OperandBundleDef
  def initialize(@unwrap : LibLLVMM::OperandBundleRef)
  end

  def self.null
    new(Pointer(::Void).null.as(LibLLVMM::OperandBundleRef))
  end

  def to_unsafe
    @unwrap
  end

  def num_args
    LibLLVMM.get_num_operand_bundle_args(self)
  end

  def arg_at_index(index)
    LLVMM::Value.new LibLLVMM.get_operand_bundle_arg_at_index(self, index)
  end

  def tag
    ptr = LibLLVMM.get_operand_bundle_tag(self, out len)
    String.new(ptr, len)
  end

  def dispose
    LibLLVMM.dispose_operand_bundle(@unwrap) if @unwrap
  end
end
