# src/llvmm/type.cr

# An LLVM type: wraps `LibLLVMM::TypeRef`.
#
# Non-owning: the underlying type is owned by its `Context` and stays valid
# for that context's lifetime. Common types are created through `Context`
# (e.g. `Context#int32`); composite types are built with the methods here.
#
# ```
# context = LLVMM::Context.new
# fun_ty = LLVMM::Type.function([context.int32, context.int32], context.int32)
# fun_ty.params_types.size # => 2
# fun_ty.varargs?          # => false
# ```
struct LLVMM::Type
  # The underlying LLVM type reference.
  getter unwrap : LibLLVMM::TypeRef

  # Wraps an existing `LibLLVMM::TypeRef` without taking ownership.
  def initialize(@unwrap : LibLLVMM::TypeRef)
  end

  # The underlying `LibLLVMM::TypeRef`, for FFI calls.
  def to_unsafe
    @unwrap
  end

  # Creates a function type taking *arg_types* and returning *return_type*.
  #
  # Set *varargs* to `true` for a C-style variadic function (`...`).
  def self.function(arg_types : Array(LLVMM::Type), return_type, varargs = false) : self
    new LibLLVMM.function_type(return_type, (arg_types.to_unsafe.as(LibLLVMM::TypeRef*)), arg_types.size, varargs ? 1 : 0)
  end

  # The ABI size of this type, as a constant `Value`.
  #
  # LLVM crashes when asked for the size of `void`; for the void type this
  # returns an `i64` constant `1` instead.
  def size
    # Asking the size of void crashes the program, we definitely don't want that
    if void?
      context.int64.const_int(1)
    else
      Value.new LibLLVMM.size_of(self)
    end
  end

  # The ABI alignment of this type, as a constant `Value`.
  #
  # LLVM crashes when asked for the alignment of `void`; for the void type
  # this returns an `i64` constant `1` instead.
  def alignment
    # Asking the alignment of void crashes the program, we definitely don't want that
    if void?
      context.int64.const_int(1)
    else
      Value.new LibLLVMM.align_of(self)
    end
  end

  # This type's `Kind`.
  def kind : LLVMM::Type::Kind
    LibLLVMM.get_type_kind(self)
  end

  # Whether this is the void type.
  def void?
    kind == Kind::Void
  end

  # The all-zeros constant of this type.
  def null
    Value.new LibLLVMM.const_null(self)
  end

  # The null pointer constant of this (pointer) type.
  def null_pointer
    Value.new LibLLVMM.const_pointer_null(self)
  end

  # The `undef` constant of this type: a value with an unspecified bit
  # pattern.
  def undef
    Value.new LibLLVMM.get_undef(self)
  end

  # An opaque pointer type in this type's context and *address_space*.
  #
  # Pointers are opaque since LLVM 15, so the receiver's kind is irrelevant
  # to the result; only its context and the address space matter.
  def pointer(address_space = 0) : LLVMM::Type
    Type.new LibLLVMM.pointer_type_in_context(LibLLVMM.get_type_context(self), address_space)
  end

  # An array type of *count* elements of this type.
  def array(count) : LLVMM::Type
    Type.new LibLLVMM.array_type2(self, count)
  end

  # A fixed-length vector type of *count* elements of this type.
  def vector(count) : self
    Type.new LibLLVMM.vector_type(self, count)
  end

  # A scalable vector type with a minimum of *count* elements of this type.
  def scalable_vector(count) : self
    Type.new LibLLVMM.scalable_vector_type(self, count)
  end

  # The bit width of this integer type.
  #
  # Raises unless this is an integer type.
  def int_width : Int32
    raise "Not an Integer" unless kind == Kind::Integer
    LibLLVMM.get_int_type_width(self).to_i32
  end

  # Whether this struct type is packed.
  #
  # Raises unless this is a struct type.
  def packed_struct? : Bool
    raise "Not a Struct" unless kind == Kind::Struct
    LibLLVMM.is_packed_struct(self) != 0
  end

  # Assuming this type is a struct, returns its name.
  # The name can be `nil` if the struct is anonymous.
  # Raises if this type is not a struct.
  def struct_name : String?
    raise "Not a Struct" unless kind == Kind::Struct

    name = LibLLVMM.get_struct_name(self)
    name ? String.new(name) : nil
  end

  # The element types of this struct type, in order.
  #
  # Raises unless this is a struct type.
  def struct_element_types : Array(LLVMM::Type)
    raise "Not a Struct" unless kind == Kind::Struct
    count = LibLLVMM.count_struct_element_types(self)

    Array(LLVMM::Type).build(count) do |buffer|
      LibLLVMM.get_struct_element_types(self, buffer.as(LibLLVMM::TypeRef*))
      count
    end
  end

  # The element type of this struct type at *index*.
  #
  # Raises unless this is a struct type.
  def struct_element_type(index) : LLVMM::Type
    raise "Not a Struct" unless kind == Kind::Struct
    Type.new LibLLVMM.struct_get_type_at_index(self, index)
  end

  # The element type of this array or (scalable) vector type.
  #
  # Raises for pointer types (typed pointers are unavailable since LLVM 15,
  # pointers are opaque) and for non-sequential types.
  def element_type : LLVMM::Type
    case kind
    when Kind::Array, Kind::Vector, Kind::ScalableVector
      Type.new LibLLVMM.get_element_type(self)
    when Kind::Pointer
      raise "Typed pointers are unavailable since LLVM 15 (opaque pointers)"
    else
      raise "Not a sequential type"
    end
  end

  # The number of elements of this array type.
  #
  # Raises unless this is an array type.
  def array_size : Int32
    raise "Not an Array" unless kind == Kind::Array
    LibLLVMM.get_array_length(self).to_i32
  end

  # The number of elements of this fixed-length vector type.
  #
  # Raises unless this is a vector type.
  def vector_size
    raise "Not a Vector" unless kind == Kind::Vector
    LibLLVMM.get_vector_size(self).to_i32
  end

  # The return type of this function type.
  #
  # Raises unless this is a function type.
  def return_type
    raise "Not a Function" unless kind == Kind::Function
    Type.new LibLLVMM.get_return_type(self)
  end

  # The parameter types of this function type, in order.
  #
  # Raises unless this is a function type.
  def params_types
    params_size = self.params_size
    Array(LLVMM::Type).build(params_size) do |buffer|
      LibLLVMM.get_param_types(self, buffer.as(LibLLVMM::TypeRef*))
      params_size
    end
  end

  # The number of parameters of this function type.
  #
  # Raises unless this is a function type.
  def params_size
    raise "Not a Function" unless kind == Kind::Function
    LibLLVMM.count_param_types(self).to_i
  end

  # Whether this function type is variadic.
  #
  # Raises unless this is a function type.
  def varargs?
    raise "Not a Function" unless kind == Kind::Function
    LibLLVMM.is_function_var_arg(self) != 0
  end

  # An integer constant of this type holding *value*.
  #
  # 128-bit values, or any value for a 128-bit integer type, are built with
  # LLVM's arbitrary-precision API; narrower values are passed directly and
  # truncated by LLVM to the type's width.
  def const_int(value) : Value
    if !value.is_a?(Int128) && !value.is_a?(UInt128) && int_width != 128
      Value.new LibLLVMM.const_int(self, value, 0)
    else
      encoded_value = UInt64[value & UInt64::MAX, (value >> 64) & UInt64::MAX]
      Value.new LibLLVMM.const_int_of_arbitrary_precision(self, encoded_value.size, encoded_value)
    end
  end

  # A real constant of this type from a `Float32`.
  def const_float(value : Float32) : Value
    Value.new LibLLVMM.const_real(self, value)
  end

  # A real constant of this type parsed from the decimal text *value*.
  def const_float(value : String) : Value
    Value.new LibLLVMM.const_real_of_string_and_size(self, value, value.bytesize)
  end

  # A real constant of this type from a `Float64`.
  def const_double(value : Float64) : Value
    Value.new LibLLVMM.const_real(self, value)
  end

  # A real constant of this type parsed from the decimal text *string*.
  def const_double(string : String) : Value
    Value.new LibLLVMM.const_real_of_string_and_size(self, string, string.bytesize)
  end

  # An array constant with this element type, holding *values*.
  def const_array(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_array(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  # An integer constant of this type parsed from *text* in base *radix*.
  def const_int(text : String, radix : Int = 10) : Value
    Value.new LibLLVMM.const_int_of_string_and_size(self, text, text.bytesize, radix.to_u8)
  end

  # A struct constant of this (struct) type, holding *values*.
  def const_named_struct(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_named_struct(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  # A constant data array holding the raw bytes of *buffer*.
  #
  # Requires LLVM 21 or newer; raises `NotImplementedError` on older
  # versions (gated on `LibLLVMM::IS_LT_210`).
  def const_data_array(buffer : Bytes) : Value
    {% if LibLLVMM::IS_LT_210 %}
      raise NotImplementedError.new("LLVMM::Type#const_data_array")
    {% else %}
      Value.new LibLLVMM.const_data_array(self, buffer, buffer.bytesize)
    {% end %}
  end

  # An inline assembly snippet whose type is this function type.
  #
  # The receiver must be a function type matching the assembly's signature;
  # the returned value is called through `Builder#call`.
  def inline_asm(asm_string, constraints, has_side_effects = false, is_align_stack = false, can_throw = false, dialect : InlineAsmDialect = InlineAsmDialect::ATT)
    value =
      LibLLVMM.get_inline_asm(
        self,
        asm_string,
        asm_string.bytesize,
        constraints,
        constraints.bytesize,
        (has_side_effects ? 1 : 0),
        (is_align_stack ? 1 : 0),
        dialect,
        (can_throw ? 1 : 0)
      )
    Value.new value
  end

  # The `Context` this type belongs to.
  #
  # The returned wrapper does not own the context (`dispose_on_finalize` is
  # `false`): it never disposes it, and the owning context must outlive this
  # type.
  def context : Context
    Context.new(LibLLVMM.get_type_context(self), dispose_on_finalize: false)
  end

  # Appends this type's LLVM IR representation to *io*.
  def inspect(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_type_to_string(self), io)
    self
  end
end
