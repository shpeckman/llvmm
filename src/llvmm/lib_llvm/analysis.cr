# src/llvmm/lib_llvm/analysis.cr
require "./types"

lib LibLLVMM
  fun verify_module = LLVMVerifyModule(m : ModuleRef, action : LLVMM::VerifierFailureAction, out_message : Char**) : Bool
end
