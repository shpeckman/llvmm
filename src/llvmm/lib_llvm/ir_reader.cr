# src/llvmm/lib_llvm/ir_reader.cr
require "./types"

lib LibLLVMM
  fun parse_ir_in_context = LLVMParseIRInContext(context_ref : ContextRef, mem_buf : MemoryBufferRef, out_m : ModuleRef*, out_message : Char**) : Bool
  {% unless LibLLVMM::IS_LT_220 %}
    fun parse_ir_in_context2 = LLVMParseIRInContext2(context_ref : ContextRef, mem_buf : MemoryBufferRef, out_m : ModuleRef*, out_message : Char**) : Bool
  {% end %}
end
