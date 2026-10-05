# src/llvmm/orc/symbol_string_pool.cr
# Wraps LLVM's ORCv2 `SymbolStringPool`, the per-`ExecutionSession` pool that
# uniquifies symbol names into reference-counted `SymbolStringPoolEntry`s.
#
# The pool is owned by its session; instances are obtained from
# `ExecutionSession#symbol_string_pool` and must not be disposed directly.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::SymbolStringPool
  protected def initialize(@unwrap : LibLLVMM::OrcSymbolStringPoolRef)
  end

  def to_unsafe
    @unwrap
  end

  # Drops the backing storage of pool entries that no longer have any live
  # references. This is a memory hint only; live entries are unaffected.
  def clear_dead_entries : Nil
    LibLLVMM.orc_symbol_string_pool_clear_dead_entries(self)
  end
end

# Wraps LLVM's ORCv2 `SymbolStringPoolEntry`, a reference-counted handle to an
# interned symbol name.
#
# Entries are not garbage collected: each `ExecutionSession#intern` or
# `LLJIT#mangle_and_intern` call hands the caller one reference, which must be
# balanced with `release` (use `retain` to take an additional reference).
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::SymbolStringPoolEntry
  protected def initialize(@unwrap : LibLLVMM::OrcSymbolStringPoolEntryRef)
  end

  def to_unsafe
    @unwrap
  end

  # Returns the interned symbol name.
  def to_s : String
    String.new(LibLLVMM.orc_symbol_string_pool_entry_str(self))
  end

  # Takes an additional reference on the entry.
  def retain : Nil
    LibLLVMM.orc_retain_symbol_string_pool_entry(self)
  end

  # Releases one reference on the entry. Safe to call more than once on this
  # wrapper: after the first call the wrapped pointer is null and further
  # calls are no-ops (each `retain`/intern reference still needs its own
  # release).
  def release : Nil
    return if @unwrap.null?
    LibLLVMM.orc_release_symbol_string_pool_entry(to_unsafe)
    @unwrap = LibLLVMM::OrcSymbolStringPoolEntryRef.null
  end
end
