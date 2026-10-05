# src/llvmm/orc/lljit.cr
# Wraps LLVM's ORCv2 `LLJIT`: a ready-made JIT stack with an execution session,
# IR transform and compile layer, object transform layer, and object linking layer.
#
# Owns the underlying `LLVMOrcLLJITRef`. Disposal happens automatically on
# `finalize`, but prefer calling `#dispose` to shut the JIT down deterministically;
# the instance must not be used afterwards.
#
# Accessors such as `#main_jit_dylib`, `#execution_session`, and the layer getters
# return wrappers borrowed from this instance; they stay valid until `#dispose`.
#
# ```
# lljit = LLVMM::Orc::LLJIT.new(LLVMM::Orc::LLJITBuilder.new)
# lljit.add_llvm_ir_module(lljit.main_jit_dylib, thread_safe_module)
# address = lljit.lookup("my_function")
# lljit.dispose
# ```
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::LLJIT
  protected def initialize(@unwrap : LibLLVMM::OrcLLJITRef)
  end

  # Builds a JIT from *builder*, consuming it: ownership of the builder transfers
  # to the new instance and the builder must not be used or disposed afterwards.
  def self.new(builder : LLJITBuilder)
    builder.take_ownership { raise "Failed to take ownership of LLVMM::Orc::LLJITBuilder" }
    LLVMM.assert LibLLVMM.orc_create_lljit(out unwrap, builder)
    new(unwrap)
  end

  def to_unsafe
    @unwrap
  end

  # Disposes the JIT, releasing all compiled code and resources. Also runs on
  # `finalize` if never called. The instance must not be used afterwards.
  def dispose : Nil
    LLVMM.assert LibLLVMM.orc_dispose_lljit(self)
    @unwrap = LibLLVMM::OrcLLJITRef.null
  end

  def finalize
    if @unwrap
      LibLLVMM.orc_dispose_lljit(self)
    end
  end

  # The JIT's main `JITDylib`: the default dylib for `#add_llvm_ir_module`,
  # `#add_object_file`, and `#lookup`. Borrowed; owned by this instance.
  def main_jit_dylib : JITDylib
    JITDylib.new(LibLLVMM.orc_lljit_get_main_jit_dylib(self))
  end

  # The `ExecutionSession` this JIT runs in. Borrowed; owned by this instance.
  def execution_session : ExecutionSession
    ExecutionSession.new(LibLLVMM.orc_lljit_get_execution_session(self))
  end

  # The target triple this JIT was built for.
  def triple_string : String
    String.new(LibLLVMM.orc_lljit_get_triple_string(self))
  end

  # The data layout string of this JIT's target.
  def data_layout_string : String
    String.new(LibLLVMM.orc_lljit_get_data_layout_str(self))
  end

  # Mangles *name* according to the JIT's data layout and interns it in the
  # execution session's symbol string pool. The returned entry is subject to
  # `SymbolStringPoolEntry`'s retain/release rules.
  def mangle_and_intern(name : String) : SymbolStringPoolEntry
    SymbolStringPoolEntry.new(LibLLVMM.orc_lljit_mangle_and_intern(self, name.check_no_null_byte))
  end

  # The object linking layer. Borrowed; owned by this instance.
  def obj_linking_layer : ObjectLayer
    ObjectLayer.new(LibLLVMM.orc_lljit_get_obj_linking_layer(self))
  end

  # The object transform layer sitting in front of `#obj_linking_layer`.
  # Borrowed; owned by this instance.
  def obj_transform_layer : ObjectTransformLayer
    ObjectTransformLayer.new(LibLLVMM.orc_lljit_get_obj_transform_layer(self))
  end

  # The IR transform layer sitting in front of the compile layer.
  # Borrowed; owned by this instance.
  def ir_transform_layer : IRTransformLayer
    IRTransformLayer.new(LibLLVMM.orc_lljit_get_ir_transform_layer(self))
  end

  # The global symbol prefix for the target (e.g. `'_'` on Mach-O), or `'\0'`
  # when the target uses none.
  def global_prefix : Char
    LibLLVMM.orc_lljit_get_global_prefix(self).unsafe_chr
  end

  # Adds the IR module in *tsm* to *dylib*, taking ownership of *tsm*; the
  # caller must not dispose it afterwards. Compilation is deferred until a
  # `#lookup` materializes the module's symbols. Raises if *tsm* was already
  # consumed or LLVM reports an error.
  def add_llvm_ir_module(dylib : JITDylib, tsm : ThreadSafeModule) : Nil
    tsm.take_ownership { raise "Failed to take ownership of LLVMM::Orc::ThreadSafeModule" }
    LLVMM.assert LibLLVMM.orc_lljit_add_llvm_ir_module(self, dylib, tsm)
  end

  # Like `#add_llvm_ir_module`, but tracks the module's resources with *tracker*
  # so they can be removed or transferred via `ResourceTracker`.
  def add_llvm_ir_module_with_rt(tracker : ResourceTracker, tsm : ThreadSafeModule) : Nil
    tsm.take_ownership { raise "Failed to take ownership of LLVMM::Orc::ThreadSafeModule" }
    LLVMM.assert LibLLVMM.orc_lljit_add_llvm_ir_module_with_rt(self, tracker, tsm)
  end

  # Adds the object file in *buffer* to *dylib*, taking ownership of *buffer*;
  # the caller must not dispose it afterwards. Passes through
  # `#obj_transform_layer` before linking. Raises if *buffer* was already
  # consumed or LLVM reports an error.
  def add_object_file(dylib : JITDylib, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_lljit_add_object_file(self, dylib, buffer)
  end

  # Like `#add_object_file`, but tracks the object's resources with *tracker*.
  def add_object_file_with_rt(tracker : ResourceTracker, buffer : LLVMM::MemoryBuffer) : Nil
    buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LLVMM.assert LibLLVMM.orc_lljit_add_object_file_with_rt(self, tracker, buffer)
  end

  # Looks up *name* in the main JITDylib, materializing code on demand, and
  # returns the symbol's address. Raises if the symbol is not found or LLVM
  # reports an error.
  def lookup(name : String) : Void*
    LLVMM.assert LibLLVMM.orc_lljit_lookup(self, out address, name.check_no_null_byte)
    Pointer(Void).new(address)
  end
end
