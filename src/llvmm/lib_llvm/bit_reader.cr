# src/llvmm/lib_llvm/bit_reader.cr
require "./types"

lib LibLLVMM
  fun parse_bitcode_in_context2 = LLVMParseBitcodeInContext2(c : ContextRef, mb : MemoryBufferRef, m : ModuleRef*) : Int
end
