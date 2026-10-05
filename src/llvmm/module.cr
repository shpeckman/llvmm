# src/llvmm/module.cr
class LLVMM::Module
  # We let a module store a reference to the context so that if
  # someone is still holding a reference to the module but not to
  # the context, the context won't be disposed (if the context is disposed,
  # the module will no longer be valid and segfaults will happen)

  getter context : Context

  def self.parse(memory_buffer : MemoryBuffer, context : Context) : self
    LibLLVMM.parse_bitcode_in_context2(context, memory_buffer, out module_ref)
    raise "BUG: failed to parse LLVMM bitcode from memory buffer" unless module_ref
    new(module_ref, context)
  end

  def initialize(@unwrap : LibLLVMM::ModuleRef, @context : Context)
    @owned = false
  end

  def name : String
    bytes = LibLLVMM.get_module_identifier(self, out bytesize)
    String.new(Slice.new(bytes, bytesize))
  end

  def name=(name : String)
    LibLLVMM.set_module_identifier(self, name, name.bytesize)
  end

  def target=(target)
    LibLLVMM.set_target(self, target)
  end

  def clone : Module
    Module.new(LibLLVMM.clone_module(self), @context)
  end

  def inline_asm : String
    bytes = LibLLVMM.get_module_inline_asm(self, out len)
    String.new(Slice.new(bytes, len))
  end

  def inline_asm=(assembly : String)
    LibLLVMM.set_module_inline_asm2(self, assembly, assembly.bytesize)
  end

  def append_inline_asm(assembly : String)
    LibLLVMM.append_module_inline_asm(self, assembly, assembly.bytesize)
  end

  def data_layout_string : String
    String.new LibLLVMM.get_data_layout_str(self)
  end

  def data_layout_string=(layout : String)
    LibLLVMM.set_data_layout(self, layout)
  end

  def data_layout=(data : TargetData)
    LibLLVMM.set_module_data_layout(self, data)
  end

  def dump
    LibLLVMM.dump_module(self)
  end

  def functions
    FunctionCollection.new(self)
  end

  def globals
    GlobalCollection.new(self)
  end

  def add_flag(module_flag : LibLLVMM::ModuleFlagBehavior, key : String, val : Int32)
    add_flag(module_flag, key, @context.int32.const_int(val))
  end

  def add_flag(module_flag : LibLLVMM::ModuleFlagBehavior, key : String, val : Value)
    LibLLVMM.add_module_flag(
      self,
      module_flag,
      key,
      key.bytesize,
      LibLLVMM.value_as_metadata(val.to_unsafe)
    )
  end

  def module_flags : Array({LibLLVMM::ModuleFlagBehavior, String, Metadata})
    entries = LibLLVMM.copy_module_flags_metadata(self, out len)
    return [] of {LibLLVMM::ModuleFlagBehavior, String, Metadata} if entries.null?
    begin
      Array.new(len.to_i) do |i|
        behavior = LibLLVMM.module_flag_entries_get_flag_behavior(entries, i)
        key_ptr  = LibLLVMM.module_flag_entries_get_key(entries, i, out key_len)
        md       = LibLLVMM.module_flag_entries_get_metadata(entries, i)
        {behavior, String.new(key_ptr, key_len), Metadata.new(md, @context)}
      end
    ensure
      LibLLVMM.dispose_module_flags_metadata(entries)
    end
  end

  def module_flag(key : String) : Metadata?
    md = LibLLVMM.get_module_flag(self, key, key.bytesize)
    md.null? ? nil : Metadata.new(md, @context)
  end

  def named_metadata : NamedMetadataCollection
    NamedMetadataCollection.new(self)
  end

  def add_global_alias(type : Type, aliasee, name : String, address_space = 0) : Value
    Value.new LibLLVMM.add_alias2(self, type, address_space, aliasee, name)
  end

  def named_global_alias(name : String) : Value?
    ga = LibLLVMM.get_named_global_alias(self, name, name.bytesize)
    ga.null? ? nil : Value.new(ga)
  end

  def each_global_alias(& : Value ->) : Nil
    ga = LibLLVMM.get_first_global_alias(self)
    until ga.null?
      yield Value.new(ga)
      ga = LibLLVMM.get_next_global_alias(ga)
    end
  end

  def add_global_ifunc(name : String, type : Type, resolver, address_space = 0) : Value
    Value.new LibLLVMM.add_global_ifunc(self, name, name.bytesize, type, address_space, resolver)
  end

  def named_global_ifunc(name : String) : Value?
    ifunc = LibLLVMM.get_named_global_ifunc(self, name, name.bytesize)
    ifunc.null? ? nil : Value.new(ifunc)
  end

  def each_global_ifunc(& : Value ->) : Nil
    ifunc = LibLLVMM.get_first_global_ifunc(self)
    until ifunc.null?
      yield Value.new(ifunc)
      ifunc = LibLLVMM.get_next_global_ifunc(ifunc)
    end
  end

  def write_bitcode_to_file(filename : String)
    LibLLVMM.write_bitcode_to_file self, filename
  end

  def debug_metadata_version : UInt32
    LibLLVMM.get_module_debug_metadata_version(self)
  end

  def strip_debug_info : Bool
    LibLLVMM.strip_module_debug_info(self) != 0
  end

  def write_bitcode_to_memory_buffer
    MemoryBuffer.new(LibLLVMM.write_bitcode_to_memory_buffer self)
  end

  def write_bitcode_to_fd(fd : Int, should_close = false, buffered = false)
    LibLLVMM.write_bitcode_to_fd(self, fd, should_close ? 1 : 0, buffered ? 0 : 1)
  end

  def verify
    error = LibLLVMM.verify_module(self, LLVMM::VerifierFailureAction::ReturnStatusAction, out message)
    begin
      if error == 1
        raise "Module validation failed: #{String.new(message)}"
      end
    ensure
      LibLLVMM.dispose_message(message)
    end
  end

  def print_to_file(filename)
    if LibLLVMM.print_module_to_file(self, filename, out error_msg) != 0
      raise LLVMM.string_and_dispose(error_msg)
    end
    self
  end

  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def to_s(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_module_to_string(self), io)
    self
  end

  def to_unsafe
    @unwrap
  end

  def take_ownership(&)
    if @owned
      yield
    else
      @owned = true
    end
  end
end
