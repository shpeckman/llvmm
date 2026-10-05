# src/llvmm/orc/symbol_string_pool.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::SymbolStringPool
  protected def initialize(@unwrap : LibLLVMM::OrcSymbolStringPoolRef)
  end

  def to_unsafe
    @unwrap
  end

  def clear_dead_entries : Nil
    LibLLVMM.orc_symbol_string_pool_clear_dead_entries(self)
  end
end

@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::SymbolStringPoolEntry
  protected def initialize(@unwrap : LibLLVMM::OrcSymbolStringPoolEntryRef)
  end

  def to_unsafe
    @unwrap
  end

  def to_s : String
    String.new(LibLLVMM.orc_symbol_string_pool_entry_str(self))
  end

  def retain : Nil
    LibLLVMM.orc_retain_symbol_string_pool_entry(self)
  end

  def release : Nil
    return if @unwrap.null?
    LibLLVMM.orc_release_symbol_string_pool_entry(to_unsafe)
    @unwrap = LibLLVMM::OrcSymbolStringPoolEntryRef.null
  end
end
