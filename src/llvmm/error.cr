# src/llvmm/error.cr
class LLVMM::Error
  def initialize(@unwrap : LibLLVMM::ErrorRef)
  end

  def self.string(message : String) : self
    new(LibLLVMM.create_string_error(message.check_no_null_byte))
  end

  def self.string_type_id : Void*
    LibLLVMM.get_string_error_type_id
  end

  def type_id : Void*
    LibLLVMM.get_error_type_id(self)
  end

  def message : String
    chars   = LibLLVMM.get_error_message(to_unsafe)
    @unwrap = Pointer(Void).null.as(LibLLVMM::ErrorRef)
    String.new(chars).tap { LibLLVMM.dispose_error_message(chars) }
  end

  def consume : Nil
    LibLLVMM.consume_error(to_unsafe)
    @unwrap = Pointer(Void).null.as(LibLLVMM::ErrorRef)
  end

  def finalize
    LibLLVMM.consume_error(@unwrap) if @unwrap
  end

  def to_unsafe
    @unwrap
  end
end
