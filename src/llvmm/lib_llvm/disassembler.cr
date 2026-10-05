# src/llvmm/lib_llvm/disassembler.cr
lib LibLLVMM
  type DisasmContextRef = Void*

  alias OpInfoCallback = Void*, UInt64, UInt64, UInt64, UInt64, Int, Void* -> Int
  alias SymbolLookupCallback = Void*, UInt64, UInt64*, UInt64, Char** -> Char*

  fun create_disasm = LLVMCreateDisasm(triple : Char*, dis_info : Void*, tag_type : Int, op_info : OpInfoCallback, symbol_lookup : SymbolLookupCallback) : DisasmContextRef
  fun create_disasm_cpu = LLVMCreateDisasmCPU(triple : Char*, cpu : Char*, dis_info : Void*, tag_type : Int, op_info : OpInfoCallback, symbol_lookup : SymbolLookupCallback) : DisasmContextRef
  fun create_disasm_cpu_features = LLVMCreateDisasmCPUFeatures(triple : Char*, cpu : Char*, features : Char*, dis_info : Void*, tag_type : Int, op_info : OpInfoCallback, symbol_lookup : SymbolLookupCallback) : DisasmContextRef
  fun set_disasm_options = LLVMSetDisasmOptions(dc : DisasmContextRef, options : UInt64) : Int
  fun disasm_dispose = LLVMDisasmDispose(dc : DisasmContextRef)
  fun disasm_instruction = LLVMDisasmInstruction(dc : DisasmContextRef, bytes : UInt8*, bytes_size : UInt64, pc : UInt64, out_string : Char*, out_string_size : SizeT) : SizeT
end
