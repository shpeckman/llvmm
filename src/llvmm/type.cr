# src/llvmm/type.cr
struct LLVMM::Type
  getter unwrap : LibLLVMM::TypeRef

  def initialize(@unwrap : LibLLVMM::TypeRef)
  end

  def to_unsafe
    @unwrap
  end

  def self.function(arg_types : Array(LLVMM::Type), return_type, varargs = false) : self
    new LibLLVMM.function_type(return_type, (arg_types.to_unsafe.as(LibLLVMM::TypeRef*)), arg_types.size, varargs ? 1 : 0)
  end

  def size
    # Asking the size of void crashes the program, we definitely don't want that
    if void?
      context.int64.const_int(1)
    else
      Value.new LibLLVMM.size_of(self)
    end
  end

  def alignment
    # Asking the alignment of void crashes the program, we definitely don't want that
    if void?
      context.int64.const_int(1)
    else
      Value.new LibLLVMM.align_of(self)
    end
  end

  def kind : LLVMM::Type::Kind
    LibLLVMM.get_type_kind(self)
  end

  def void?
    kind == Kind::Void
  end

  def null
    Value.new LibLLVMM.const_null(self)
  end

  def null_pointer
    Value.new LibLLVMM.const_pointer_null(self)
  end

  def undef
    Value.new LibLLVMM.get_undef(self)
  end

  def pointer(address_space = 0) : LLVMM::Type
    Type.new LibLLVMM.pointer_type_in_context(LibLLVMM.get_type_context(self), address_space)
  end

  def array(count) : LLVMM::Type
    Type.new LibLLVMM.array_type2(self, count)
  end

  def vector(count) : self
    Type.new LibLLVMM.vector_type(self, count)
  end

  def scalable_vector(count) : self
    Type.new LibLLVMM.scalable_vector_type(self, count)
  end

  def int_width : Int32
    raise "Not an Integer" unless kind == Kind::Integer
    LibLLVMM.get_int_type_width(self).to_i32
  end

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

  def struct_element_types : Array(LLVMM::Type)
    raise "Not a Struct" unless kind == Kind::Struct
    count = LibLLVMM.count_struct_element_types(self)

    Array(LLVMM::Type).build(count) do |buffer|
      LibLLVMM.get_struct_element_types(self, buffer.as(LibLLVMM::TypeRef*))
      count
    end
  end

  def struct_element_type(index) : LLVMM::Type
    raise "Not a Struct" unless kind == Kind::Struct
    Type.new LibLLVMM.struct_get_type_at_index(self, index)
  end

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

  def array_size : Int32
    raise "Not an Array" unless kind == Kind::Array
    LibLLVMM.get_array_length(self).to_i32
  end

  def vector_size
    raise "Not a Vector" unless kind == Kind::Vector
    LibLLVMM.get_vector_size(self).to_i32
  end

  def return_type
    raise "Not a Function" unless kind == Kind::Function
    Type.new LibLLVMM.get_return_type(self)
  end

  def params_types
    params_size = self.params_size
    Array(LLVMM::Type).build(params_size) do |buffer|
      LibLLVMM.get_param_types(self, buffer.as(LibLLVMM::TypeRef*))
      params_size
    end
  end

  def params_size
    raise "Not a Function" unless kind == Kind::Function
    LibLLVMM.count_param_types(self).to_i
  end

  def varargs?
    raise "Not a Function" unless kind == Kind::Function
    LibLLVMM.is_function_var_arg(self) != 0
  end

  def const_int(value) : Value
    if !value.is_a?(Int128) && !value.is_a?(UInt128) && int_width != 128
      Value.new LibLLVMM.const_int(self, value, 0)
    else
      encoded_value = UInt64[value & UInt64::MAX, (value >> 64) & UInt64::MAX]
      Value.new LibLLVMM.const_int_of_arbitrary_precision(self, encoded_value.size, encoded_value)
    end
  end

  def const_float(value : Float32) : Value
    Value.new LibLLVMM.const_real(self, value)
  end

  def const_float(value : String) : Value
    Value.new LibLLVMM.const_real_of_string_and_size(self, value, value.bytesize)
  end

  def const_double(value : Float64) : Value
    Value.new LibLLVMM.const_real(self, value)
  end

  def const_double(string : String) : Value
    Value.new LibLLVMM.const_real_of_string_and_size(self, string, string.bytesize)
  end

  def const_array(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_array(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  def const_int(text : String, radix : Int = 10) : Value
    Value.new LibLLVMM.const_int_of_string_and_size(self, text, text.bytesize, radix.to_u8)
  end

  def const_named_struct(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_named_struct(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  def const_data_array(buffer : Bytes) : Value
    {% if LibLLVMM::IS_LT_210 %}
      raise NotImplementedError.new("LLVMM::Type#const_data_array")
    {% else %}
      Value.new LibLLVMM.const_data_array(self, buffer, buffer.bytesize)
    {% end %}
  end

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

  def context : Context
    Context.new(LibLLVMM.get_type_context(self), dispose_on_finalize: false)
  end

  def inspect(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_type_to_string(self), io)
    self
  end
end
