# src/llvmm/lib_llvm/error.cr
lib LibLLVMM
  type ErrorRef = Void*
  alias ErrorTypeId = Void*

  fun get_error_message = LLVMGetErrorMessage(err : ErrorRef) : Char*
  fun dispose_error_message = LLVMDisposeErrorMessage(err_msg : Char*)
  fun consume_error = LLVMConsumeError(err : ErrorRef)
  fun create_string_error = LLVMCreateStringError(err_msg : Char*) : ErrorRef
  fun get_error_type_id = LLVMGetErrorTypeId(err : ErrorRef) : ErrorTypeId
  fun get_string_error_type_id = LLVMGetStringErrorTypeId : ErrorTypeId
  {% unless LibLLVMM::IS_LT_200 %}
    fun cant_fail = LLVMCantFail(err : ErrorRef)
  {% end %}
end
