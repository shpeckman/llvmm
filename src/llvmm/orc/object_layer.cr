# src/llvmm/orc/object_layer.cr
# Wraps LLVM's ORCv2 `ObjectLayer` (typically an `RTDyldObjectLinkingLayer`),
# which links object files into the JIT.
#
# Instances are borrowed from `LLJIT#obj_linking_layer`; they are not disposed
# independently and stay valid until the owning `LLJIT` is disposed. Objects
# added directly through this layer bypass the `ObjectTransformLayer`.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ObjectLayer
  protected def initialize(@unwrap : LibLLVMM::OrcObjectLayerRef)
  end

  def to_unsafe
    @unwrap
  end

  # Links the object file in *buffer* into *dylib*, taking ownership of
  # *buffer*; the caller must not dispose it afterwards. Raises if *buffer* was
  # already consumed or LLVM reports an error.
  def add_object_file(dylib : JITDylib, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_object_layer_add_object_file(self, dylib, buffer)
  end

  # Like `#add_object_file`, but tracks the object's resources with *tracker*
  # so they can be removed or transferred via `ResourceTracker`.
  def add_object_file_with_rt(tracker : ResourceTracker, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_object_layer_add_object_file_with_rt(self, tracker, buffer)
  end
end
