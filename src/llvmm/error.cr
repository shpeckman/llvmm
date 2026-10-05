# src/llvmm/error.cr

# An ORC JIT error, wrapping LLVM's `LLVMErrorRef`.
#
# An `Error` owns its underlying reference until it is consumed. Calling
# `#message` or `#consume` disposes of the error and renders the instance
# inert; if neither is called, the error is consumed when the instance is
# garbage-collected. Instances are typically delivered to the
# `Orc::ExecutionSession#on_error` reporter. After consumption the instance
# must not be inspected again.
class LLVMM::Error
  def initialize(@unwrap : LibLLVMM::ErrorRef)
  end

  # Creates a string error carrying *message*, tagged with `.string_type_id`.
  def self.string(message : String) : self
    new(LibLLVMM.create_string_error(message.check_no_null_byte))
  end

  # The type id shared by all errors created with `.string`.
  def self.string_type_id : Void*
    LibLLVMM.get_string_error_type_id
  end

  # The type id of this error. Compare against `.string_type_id` or a custom
  # error's id to distinguish error kinds.
  def type_id : Void*
    LibLLVMM.get_error_type_id(self)
  end

  # Returns the error message and consumes the error.
  #
  # This instance becomes inert afterwards and must not be used again.
  def message : String
    chars   = LibLLVMM.get_error_message(to_unsafe)
    @unwrap = Pointer(Void).null.as(LibLLVMM::ErrorRef)
    String.new(chars).tap { LibLLVMM.dispose_error_message(chars) }
  end

  # Disposes of the error without inspecting it. This instance becomes
  # inert afterwards.
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
