# src/llvmm/orc/lljit.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::LLJIT
  protected def initialize(@unwrap : LibLLVMM::OrcLLJITRef)
  end

  def self.new(builder : LLJITBuilder)
    builder.take_ownership { raise "Failed to take ownership of LLVMM::Orc::LLJITBuilder" }
    LLVMM.assert LibLLVMM.orc_create_lljit(out unwrap, builder)
    new(unwrap)
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LLVMM.assert LibLLVMM.orc_dispose_lljit(self)
    @unwrap = LibLLVMM::OrcLLJITRef.null
  end

  def finalize
    if @unwrap
      LibLLVMM.orc_dispose_lljit(self)
    end
  end

  def main_jit_dylib : JITDylib
    JITDylib.new(LibLLVMM.orc_lljit_get_main_jit_dylib(self))
  end

  def execution_session : ExecutionSession
    ExecutionSession.new(LibLLVMM.orc_lljit_get_execution_session(self))
  end

  def triple_string : String
    String.new(LibLLVMM.orc_lljit_get_triple_string(self))
  end

  def data_layout_string : String
    String.new(LibLLVMM.orc_lljit_get_data_layout_str(self))
  end

  def mangle_and_intern(name : String) : SymbolStringPoolEntry
    SymbolStringPoolEntry.new(LibLLVMM.orc_lljit_mangle_and_intern(self, name.check_no_null_byte))
  end

  def obj_linking_layer : ObjectLayer
    ObjectLayer.new(LibLLVMM.orc_lljit_get_obj_linking_layer(self))
  end

  def obj_transform_layer : ObjectTransformLayer
    ObjectTransformLayer.new(LibLLVMM.orc_lljit_get_obj_transform_layer(self))
  end

  def ir_transform_layer : IRTransformLayer
    IRTransformLayer.new(LibLLVMM.orc_lljit_get_ir_transform_layer(self))
  end

  def global_prefix : Char
    LibLLVMM.orc_lljit_get_global_prefix(self).unsafe_chr
  end

  def add_llvm_ir_module(dylib : JITDylib, tsm : ThreadSafeModule) : Nil
    tsm.take_ownership { raise "Failed to take ownership of LLVMM::Orc::ThreadSafeModule" }
    LLVMM.assert LibLLVMM.orc_lljit_add_llvm_ir_module(self, dylib, tsm)
  end

  def add_llvm_ir_module_with_rt(tracker : ResourceTracker, tsm : ThreadSafeModule) : Nil
    tsm.take_ownership { raise "Failed to take ownership of LLVMM::Orc::ThreadSafeModule" }
    LLVMM.assert LibLLVMM.orc_lljit_add_llvm_ir_module_with_rt(self, tracker, tsm)
  end

  def add_object_file(dylib : JITDylib, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_lljit_add_object_file(self, dylib, buffer)
  end

  def add_object_file_with_rt(tracker : ResourceTracker, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_lljit_add_object_file_with_rt(self, tracker, buffer)
  end

  def lookup(name : String) : Void*
    LLVMM.assert LibLLVMM.orc_lljit_lookup(self, out address, name.check_no_null_byte)
    Pointer(Void).new(address)
  end
end
