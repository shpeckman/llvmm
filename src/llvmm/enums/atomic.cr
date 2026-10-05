# src/llvmm/enums/atomic.cr
module LLVMM
  # Memory orderings for atomic instructions and fences (values match
  # LLVM's `LLVMAtomicOrdering`; the gap at value 3 is upstream numbering).
  enum AtomicOrdering
    NotAtomic              = 0
    Unordered              = 1
    Monotonic              = 2
    Acquire                = 4
    Release                = 5
    AcquireRelease         = 6
    SequentiallyConsistent = 7
  end

  # Operations performed by an `atomicrmw` instruction (see
  # `ValueMethods#atomicrmw_bin_op`).
  enum AtomicRMWBinOp
    Xchg
    Add
    Sub
    And
    Nand
    Or
    Xor
    Max
    Min
    Umax
    Umin
    Fadd
    Fsub
  end
end
