# src/llvmm/orc/resource_tracker.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ResourceTracker
  protected def initialize(@unwrap : LibLLVMM::OrcResourceTrackerRef, @owned = true)
  end

  def to_unsafe
    @unwrap
  end

  def release : Nil
    raise "Cannot release a borrowed LLVMM::Orc::ResourceTracker" unless @owned
    return if @unwrap.null?
    LibLLVMM.orc_release_resource_tracker(to_unsafe)
    @unwrap = LibLLVMM::OrcResourceTrackerRef.null
  end

  def transfer_to(dst : ResourceTracker) : Nil
    LibLLVMM.orc_resource_tracker_transfer_to(self, dst)
  end

  def remove : Nil
    LLVMM.assert LibLLVMM.orc_resource_tracker_remove(self)
  end
end
