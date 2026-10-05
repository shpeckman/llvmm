# src/llvmm/orc/ir_transform_layer.cr
# Wraps LLVM's ORCv2 `IRTransformLayer`, which applies a user transform to each
# `ThreadSafeModule` before it reaches the compile layer.
#
# Instances are borrowed from `LLJIT#ir_transform_layer`; they are not disposed
# independently and stay valid until the owning `LLJIT` is disposed.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::IRTransformLayer
  protected def initialize(@unwrap : LibLLVMM::OrcIRTransformLayerRef)
    @transform     = nil
    @transform_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  # Sets the transform applied to every module passing through this layer.
  #
  # The block receives the module (borrowed — the layer keeps ownership) and the
  # `MaterializationResponsibility`, and may modify the module in place. The
  # block's return value is ignored and the wrapper always reports success to
  # LLVM, so exceptions must not escape the block. The block is kept alive by
  # this wrapper and may be called from JIT worker threads.
  def set_transform(&transform : ThreadSafeModule, LibLLVMM::OrcMaterializationResponsibilityRef ->) : Nil
    @transform     = transform
    @transform_box = Box.box(transform)
    LibLLVMM.orc_ir_transform_layer_set_transform(self, ->(ctx : Void*, mod_in_out : LibLLVMM::OrcThreadSafeModuleRef*, mr : LibLLVMM::OrcMaterializationResponsibilityRef) {
      tsm = ThreadSafeModule.new(mod_in_out.value, dispose_on_finalize: false)
      Box(Proc(ThreadSafeModule, LibLLVMM::OrcMaterializationResponsibilityRef, Nil)).unbox(ctx).call(tsm, mr)
      Pointer(Void).null.as(LibLLVMM::ErrorRef)
    }, @transform_box)
  end
end
