# src/llvmm/orc/execution_session.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ExecutionSession
  protected def initialize(@unwrap : LibLLVMM::OrcExecutionSessionRef)
    @error_reporter     = nil
    @error_reporter_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  def intern(name : String) : SymbolStringPoolEntry
    SymbolStringPoolEntry.new(LibLLVMM.orc_execution_session_intern(self, name.check_no_null_byte))
  end

  def symbol_string_pool : SymbolStringPool
    SymbolStringPool.new(LibLLVMM.orc_execution_session_get_symbol_string_pool(self))
  end

  def [](name : String) : JITDylib?
    if jd = LibLLVMM.orc_execution_session_get_jit_dylib_by_name(self, name.check_no_null_byte)
      JITDylib.new(jd)
    end
  end

  def create_bare_jit_dylib(name : String) : JITDylib
    JITDylib.new(LibLLVMM.orc_execution_session_create_bare_jit_dylib(self, name.check_no_null_byte))
  end

  def create_jit_dylib(name : String) : JITDylib
    LLVMM.assert LibLLVMM.orc_execution_session_create_jit_dylib(self, out jd, name.check_no_null_byte)
    JITDylib.new(jd)
  end

  def on_error(&reporter : LLVMM::Error ->) : Nil
    @error_reporter     = reporter
    @error_reporter_box = Box.box(reporter)
    LibLLVMM.orc_execution_session_set_error_reporter(self, ->(ctx : Void*, err : LibLLVMM::ErrorRef) {
      Box(Proc(LLVMM::Error, Nil)).unbox(ctx).call(LLVMM::Error.new(err))
    }, @error_reporter_box)
  end
end
