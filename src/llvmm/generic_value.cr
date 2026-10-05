# src/llvmm/generic_value.cr

# A generic execution-engine result value, wrapping LLVM's
# `LLVMGenericValueRef`.
#
# `GenericValue` is how the legacy execution engine and the JIT return
# values from executed functions (see `JITCompiler`). It owns its
# underlying reference and disposes of it when garbage-collected; there is
# no explicit `#dispose`. The `Context` passed at construction is only used
# to interpret float results.
class LLVMM::GenericValue
  def initialize(@unwrap : LibLLVMM::GenericValueRef, @context : LLVMM::Context)
  end

  # The value as a signed 32-bit integer. Overflows if the value does not
  # fit in `Int32`.
  def to_i : Int32
    to_i64.to_i32!
  end

  # The value interpreted as a signed 64-bit integer.
  def to_i64 : Int64
    LibLLVMM.generic_value_to_int(self, is_signed: 1).to_i64!
  end

  # The value interpreted as an unsigned 64-bit integer.
  def to_u64 : UInt64
    LibLLVMM.generic_value_to_int(self, is_signed: 0)
  end

  # The value as a boolean: `false` when the integer value is zero.
  def to_b : Bool
    to_i != 0
  end

  # The value interpreted as a single-precision float, using the context's
  # float type.
  def to_f32 : Float32
    LibLLVMM.generic_value_to_float(@context.float, self).to_f32
  end

  # The value interpreted as a double-precision float, using the context's
  # double type.
  def to_f64 : Float64
    LibLLVMM.generic_value_to_float(@context.double, self)
  end

  # The value as a `String`, interpreting the underlying pointer as a
  # pointer to a Crystal `String`.
  def to_string : String
    to_pointer.as(String)
  end

  # The raw pointer value.
  def to_pointer : Void*
    LibLLVMM.generic_value_to_pointer(self)
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVMM.dispose_generic_value(@unwrap)
  end
end
