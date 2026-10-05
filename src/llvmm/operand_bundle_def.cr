# src/llvmm/operand_bundle_def.cr

# An operand bundle ("deopt", "funclet", …) attached to a call or invoke
# instruction, wrapping LLVM's `LLVMOperandBundleRef`.
#
# Ownership depends on how the bundle was obtained: a bundle created with
# `Builder#build_operand_bundle_def` is owned by the caller and should be
# released with `#dispose` once it has been used, whereas a bundle read
# back from a call site with `ValueMethods#operand_bundle_at_index` is
# borrowed from that instruction and must not be disposed.
struct LLVMM::OperandBundleDef
  def initialize(@unwrap : LibLLVMM::OperandBundleRef)
  end

  # An operand bundle wrapping a null reference.
  def self.null
    new(Pointer(::Void).null.as(LibLLVMM::OperandBundleRef))
  end

  def to_unsafe
    @unwrap
  end

  # The number of arguments in the bundle.
  def num_args
    LibLLVMM.get_num_operand_bundle_args(self)
  end

  # The argument at *index*.
  def arg_at_index(index)
    LLVMM::Value.new LibLLVMM.get_operand_bundle_arg_at_index(self, index)
  end

  # The bundle's tag (e.g. `"deopt"`).
  def tag
    ptr = LibLLVMM.get_operand_bundle_tag(self, out len)
    String.new(ptr, len)
  end

  # Releases the bundle. Only call this on bundles created with
  # `Builder#build_operand_bundle_def`, never on bundles borrowed from a
  # call site. Safe to call on a null bundle.
  def dispose
    LibLLVMM.dispose_operand_bundle(@unwrap) if @unwrap
  end
end
