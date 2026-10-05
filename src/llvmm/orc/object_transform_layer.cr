# src/llvmm/orc/object_transform_layer.cr
# Wraps LLVM's ORCv2 `ObjectTransformLayer`, which applies a user transform to
# each object file buffer before it reaches the object linking layer.
#
# Instances are borrowed from `LLJIT#obj_transform_layer`; they are not disposed
# independently and stay valid until the owning `LLJIT` is disposed. Only
# objects added via `LLJIT#add_object_file` pass through this layer.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ObjectTransformLayer
  protected def initialize(@unwrap : LibLLVMM::OrcObjectTransformLayerRef)
    @transform_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  # Sets the transform applied to every object buffer passing through this
  # layer.
  #
  # The block receives a pointer to the object file's `MemoryBuffer` ref and may
  # replace the buffer through that pointer (e.g. via a dump-objects operator).
  # The block's return value is ignored and the wrapper always reports success
  # to LLVM, so exceptions must not escape the block. The block is kept alive by
  # this wrapper and may be called from JIT worker threads.
  def set_transform(&transform : LibLLVMM::MemoryBufferRef* -> R) : Nil forall R
    @transform_box = Box.box(transform)
    LibLLVMM.orc_object_transform_layer_set_transform(self, ->(ctx : Void*, obj_in_out : LibLLVMM::MemoryBufferRef*) {
      Box(Proc(LibLLVMM::MemoryBufferRef*, R)).unbox(ctx).call(obj_in_out)
      Pointer(Void).null.as(LibLLVMM::ErrorRef)
    }, @transform_box)
  end
end
