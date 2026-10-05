# src/llvmm/orc/object_transform_layer.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ObjectTransformLayer
  protected def initialize(@unwrap : LibLLVMM::OrcObjectTransformLayerRef)
    @transform_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  def set_transform(&transform : LibLLVMM::MemoryBufferRef* -> R) : Nil forall R
    @transform_box = Box.box(transform)
    LibLLVMM.orc_object_transform_layer_set_transform(self, ->(ctx : Void*, obj_in_out : LibLLVMM::MemoryBufferRef*) {
      Box(Proc(LibLLVMM::MemoryBufferRef*, R)).unbox(ctx).call(obj_in_out)
      Pointer(Void).null.as(LibLLVMM::ErrorRef)
    }, @transform_box)
  end
end
