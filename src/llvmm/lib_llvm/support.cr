# src/llvmm/lib_llvm/support.cr
lib LibLLVMM
  fun parse_command_line_options = LLVMParseCommandLineOptions(argc : Int, argv : Char**, overview : Char*)
  fun add_symbol = LLVMAddSymbol(symbol_name : Char*, symbol_value : Void*)

  fun create_memory_buffer_with_memory_range = LLVMCreateMemoryBufferWithMemoryRange(input_data : Char*, input_data_length : SizeT, buffer_name : Char*, requires_null_terminator : Bool) : MemoryBufferRef
  fun create_memory_buffer_with_memory_range_copy = LLVMCreateMemoryBufferWithMemoryRangeCopy(input_data : Char*, input_data_length : SizeT, buffer_name : Char*) : MemoryBufferRef
end
