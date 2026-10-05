# src/llvmm/orc/execution_session.cr
# Wraps LLVM's ORCv2 `ExecutionSession`, the top-level ORC context that owns
# the symbol string pool and every `JITDylib` of a JIT instance.
#
# Instances are obtained from `LLJIT#execution_session`. The underlying session
# is owned by the JIT and is disposed together with it; this wrapper never
# takes ownership.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::ExecutionSession
  protected def initialize(@unwrap : LibLLVMM::OrcExecutionSessionRef)
    @error_reporter     = nil
    @error_reporter_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  # Interns *name* in the session's symbol string pool and returns the pooled
  # entry. Interning the same name twice yields the same underlying entry.
  #
  # The caller owns a reference to the returned entry and must call
  # `SymbolStringPoolEntry#release` on it when done.
  def intern(name : String) : SymbolStringPoolEntry
    SymbolStringPoolEntry.new(LibLLVMM.orc_execution_session_intern(self, name.check_no_null_byte))
  end

  # Returns the session's symbol string pool. The pool is owned by the session.
  def symbol_string_pool : SymbolStringPool
    SymbolStringPool.new(LibLLVMM.orc_execution_session_get_symbol_string_pool(self))
  end

  # Returns the `JITDylib` named *name*, or `nil` if the session has no dylib
  # with that name.
  def [](name : String) : JITDylib?
    if jd = LibLLVMM.orc_execution_session_get_jit_dylib_by_name(self, name.check_no_null_byte)
      JITDylib.new(jd)
    end
  end

  # Creates a new `JITDylib` with no definition generators and no link order.
  # The dylib is owned by the session and lives until the JIT is disposed.
  def create_bare_jit_dylib(name : String) : JITDylib
    JITDylib.new(LibLLVMM.orc_execution_session_create_bare_jit_dylib(self, name.check_no_null_byte))
  end

  # Creates a new `JITDylib` whose link order contains the dylib itself.
  # Raises `LLVMM::Error` if the session refuses the creation (e.g. the name
  # is already taken).
  def create_jit_dylib(name : String) : JITDylib
    LLVMM.assert LibLLVMM.orc_execution_session_create_jit_dylib(self, out jd, name.check_no_null_byte)
    JITDylib.new(jd)
  end

  # Registers *reporter* as the session's error reporter, replacing any
  # previously registered one. The reporter is invoked with each error that
  # reaches the session, e.g. failing lazy symbol resolutions.
  def on_error(&reporter : LLVMM::Error ->) : Nil
    @error_reporter     = reporter
    @error_reporter_box = Box.box(reporter)
    LibLLVMM.orc_execution_session_set_error_reporter(self, ->(ctx : Void*, err : LibLLVMM::ErrorRef) {
      Box(Proc(LLVMM::Error, Nil)).unbox(ctx).call(LLVMM::Error.new(err))
    }, @error_reporter_box)
  end
end
