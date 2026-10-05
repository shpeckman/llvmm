# src/llvmm/context.cr
class LLVMM::Context
  def self.new(*, dispose_on_finalize : Bool = true)
    new(LibLLVMM.create_context, dispose_on_finalize)
  end

  def initialize(@unwrap : LibLLVMM::ContextRef, @dispose_on_finalize = true)
    @disposed               = false
    @builders               = [] of LLVMM::Builder
    @diagnostic_handler     = nil
    @diagnostic_handler_box = Pointer(Void).null
  end

  def on_diagnostic(&handler : LLVMM::DiagnosticSeverity, String ->) : Nil
    @diagnostic_handler     = handler
    @diagnostic_handler_box = Box.box(handler)
    LibLLVMM.set_diagnostic_handler(self, ->(di : LibLLVMM::DiagnosticInfoRef, opaque : Void*) {
      callback = Box(Proc(LLVMM::DiagnosticSeverity, String, Void)).unbox(opaque)
      severity = LibLLVMM.get_diag_info_severity(di)
      message  = LLVMM.string_and_dispose(LibLLVMM.get_diag_info_description(di))
      callback.call(severity, message)
    }, @diagnostic_handler_box)
  end

  def discard_value_names=(discard : Bool)
    LibLLVMM.set_discard_value_names(self, discard)
    discard
  end

  def discard_value_names? : Bool
    LibLLVMM.should_discard_value_names(self) != 0
  end

  def new_module(name : String) : Module
    Module.new(LibLLVMM.module_create_with_name_in_context(name, self), self)
  end

  def new_builder : Builder
    # builder = Builder.new(LibLLVMM.create_builder_in_context(self), self)
    builder = Builder.new(LibLLVMM.create_builder_in_context(self))
    @builders << builder
    builder
  end

  def void : Type
    Type.new LibLLVMM.void_type_in_context(self)
  end

  def int1 : Type
    Type.new LibLLVMM.int1_type_in_context(self)
  end

  def int8 : Type
    Type.new LibLLVMM.int8_type_in_context(self)
  end

  def int16 : Type
    Type.new LibLLVMM.int16_type_in_context(self)
  end

  def int32 : Type
    Type.new LibLLVMM.int32_type_in_context(self)
  end

  def int64 : Type
    Type.new LibLLVMM.int64_type_in_context(self)
  end

  def int128 : Type
    Type.new LibLLVMM.int128_type_in_context(self)
  end

  def int(bits : Int) : Type
    Type.new LibLLVMM.int_type_in_context(self, bits)
  end

  def half : Type
    Type.new LibLLVMM.half_type_in_context(self)
  end

  def bfloat : Type
    Type.new LibLLVMM.bfloat_type_in_context(self)
  end

  def float : Type
    Type.new LibLLVMM.float_type_in_context(self)
  end

  def double : Type
    Type.new LibLLVMM.double_type_in_context(self)
  end

  def x86_fp80 : Type
    Type.new LibLLVMM.x86_fp80_type_in_context(self)
  end

  def fp128 : Type
    Type.new LibLLVMM.fp128_type_in_context(self)
  end

  def ppc_fp128 : Type
    Type.new LibLLVMM.ppc_fp128_type_in_context(self)
  end

  def x86_amx : Type
    Type.new LibLLVMM.x86_amx_type_in_context(self)
  end

  def token : Type
    Type.new LibLLVMM.token_type_in_context(self)
  end

  def pointer(address_space = 0) : Type
    Type.new LibLLVMM.pointer_type_in_context(self, address_space)
  end

  def void_pointer(address_space = 0) : Type
    pointer(address_space)
  end

  def struct(name : String, packed = false, &) : Type
    llvm_struct   = LibLLVMM.struct_create_named(self, name)
    the_struct    = Type.new llvm_struct
    element_types = (yield the_struct).as(Array(LLVMM::Type))
    LibLLVMM.struct_set_body(llvm_struct, (element_types.to_unsafe.as(LibLLVMM::TypeRef*)), element_types.size, packed ? 1 : 0)
    the_struct
  end

  def struct(element_types : Array(LLVMM::Type), name = nil, packed = false) : Type
    if name
      self.struct(name, packed) { element_types }
    else
      Type.new LibLLVMM.struct_type_in_context(self, (element_types.to_unsafe.as(LibLLVMM::TypeRef*)), element_types.size, packed ? 1 : 0)
    end
  end

  def const_string(string : String) : Value
    const_bytes(string.unsafe_byte_slice(0, string.bytesize + 1))
  end

  def const_bytes(bytes : Bytes) : Value
    {% if LibLLVMM::IS_LT_190 %}
      Value.new LibLLVMM.const_string_in_context(self, bytes, bytes.size, 1)
    {% else %}
      Value.new LibLLVMM.const_string_in_context2(self, bytes, bytes.size, 1)
    {% end %}
  end

  def const_struct(values : Array(LLVMM::Value), packed = false) : Value
    Value.new LibLLVMM.const_struct_in_context(self, (values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size, packed ? 1 : 0)
  end

  def const_vector(values : Array(LLVMM::Value)) : Value
    Value.new LibLLVMM.const_vector((values.to_unsafe.as(LibLLVMM::ValueRef*)), values.size)
  end

  def const_ptr_auth(ptr, key, disc, addr_disc) : Value
    {% if LibLLVMM::IS_LT_190 %}
      raise NotImplementedError.new("LLVMM::Context#const_ptr_auth")
    {% else %}
      Value.new LibLLVMM.constant_ptr_auth(ptr, key, disc, addr_disc)
    {% end %}
  end

  def md_string(value : String) : Value
    LLVMM::Value.new LibLLVMM.md_string_in_context2(self, value, value.bytesize)
  end

  def md_node(mds : Array(LibLLVMM::MetadataRef)) : LibLLVMM::MetadataRef
    LibLLVMM.md_node_in_context2(self, mds.to_unsafe, mds.size)
  end

  def md_node(values : Array(Value)) : LibLLVMM::MetadataRef
    md_node(values.map { |value| LibLLVMM.value_as_metadata(value) })
  end

  def temporary_md_node(mds : Array(LibLLVMM::MetadataRef)) : LibLLVMM::MetadataRef
    LibLLVMM.temporary_md_node(self, mds.to_unsafe, mds.size)
  end

  def metadata_type : Type
    Type.new LibLLVMM.metadata_type_in_context(self)
  end

  def parse_ir(buf : MemoryBuffer)
    ret = LibLLVMM.parse_ir_in_context(self, buf, out mod, out msg)
    if ret != 0 && msg
      raise LLVMM.string_and_dispose(msg)
    end
    Module.new(mod, self)
  end

  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def to_unsafe
    @unwrap
  end

  def take_ownership(&)
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end

  def finalize
    return if @disposed
    @disposed = true

    @builders.each &.dispose

    LibLLVMM.dispose_context(self) if @dispose_on_finalize
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # @@info = {} of UInt64 => String

  # def self.register(context : Context, name : String)
  #   @@info[context.@unwrap.address] = name
  # end

  # def self.lookup(context : Context)
  #   @@info[context.@unwrap.address]? || "global"
  # end

  # def self.wrong(expected, got, msg)
  #   raise "#{msg} (expected #{lookup(expected)}, got #{lookup(got)})"
  # end
end
