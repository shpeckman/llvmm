# src/llvmm/orc/object_layer.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ObjectLayer
  protected def initialize(@unwrap : LibLLVMM::OrcObjectLayerRef)
  end

  def to_unsafe
    @unwrap
  end

  def add_object_file(dylib : JITDylib, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_object_layer_add_object_file(self, dylib, buffer)
  end

  def add_object_file_with_rt(tracker : ResourceTracker, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_object_layer_add_object_file_with_rt(self, tracker, buffer)
  end
end
