# src/llvmm/orc/resource_tracker.cr
# Wraps LLVM's ORCv2 `ResourceTracker`, which groups the resources (allocated
# memory, symbol definitions) of JIT'd code so they can be transferred or
# removed as a unit.
#
# Trackers created via `JITDylib#create_resource_tracker` are owned by the
# caller and must be disposed with `release` once no longer needed. The
# tracker returned by `JITDylib#default_resource_tracker` is borrowed from the
# dylib — calling `release` on it raises.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ResourceTracker
  protected def initialize(@unwrap : LibLLVMM::OrcResourceTrackerRef, @owned = true)
  end

  def to_unsafe
    @unwrap
  end

  # Releases the tracker, detaching it from its dylib; resources it still
  # tracks are unaffected. Raises if this wrapper is borrowed (see
  # `JITDylib#default_resource_tracker`). After release the wrapped pointer is
  # null and the wrapper must not be used again.
  def release : Nil
    raise "Cannot release a borrowed LLVMM::Orc::ResourceTracker" unless @owned
    return if @unwrap.null?
    LibLLVMM.orc_release_resource_tracker(to_unsafe)
    @unwrap = LibLLVMM::OrcResourceTrackerRef.null
  end

  # Moves all resources tracked by this tracker to *dst*, leaving this tracker
  # empty.
  def transfer_to(dst : ResourceTracker) : Nil
    LibLLVMM.orc_resource_tracker_transfer_to(self, dst)
  end

  # Removes all resources tracked by this tracker: tracked memory is freed and
  # associated symbols stop resolving. Raises `LLVMM::Error` on failure.
  def remove : Nil
    LLVMM.assert LibLLVMM.orc_resource_tracker_remove(self)
  end
end
