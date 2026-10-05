# src/llvmm/orc/ir_transform_layer.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::IRTransformLayer
  protected def initialize(@unwrap : LibLLVMM::OrcIRTransformLayerRef)
    @transform     = nil
    @transform_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

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
