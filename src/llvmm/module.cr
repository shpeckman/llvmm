# src/llvmm/module.cr
# An LLVM module (`LLVMModule`): the top-level container of functions,
# global variables, aliases, ifuncs, module flags, and named metadata.
#
# A module is owned by its `Context`: it is destroyed when the context is
# disposed, and it keeps a reference to the context so the context cannot be
# finalized while the module is still reachable. Use `take_ownership` to mark
# the module as handed off (e.g. to the JIT).
class LLVMM::Module
  # We let a module store a reference to the context so that if
  # someone is still holding a reference to the module but not to
  # the context, the context won't be disposed (if the context is disposed,
  # the module will no longer be valid and segfaults will happen)

  # The context this module belongs to.
  getter context : Context

  # Parses LLVM bitcode from *memory_buffer* in *context* and returns the
  # resulting module. LLVM consumes the buffer (ownership is transferred, as
  # with `MemoryBuffer#take_ownership`), so this raises if the buffer was
  # already consumed.
  def self.parse(memory_buffer : MemoryBuffer, context : Context) : self
    memory_buffer.take_ownership { raise "Failed to take ownership of LLVMM::MemoryBuffer" }
    LibLLVMM.parse_bitcode_in_context2(context, memory_buffer, out module_ref)
    raise "BUG: failed to parse LLVMM bitcode from memory buffer" unless module_ref
    new(module_ref, context)
  end

  # Wraps an existing `LibLLVMM::ModuleRef` belonging to *context*.
  def initialize(@unwrap : LibLLVMM::ModuleRef, @context : Context)
    @owned = false
  end

  # The module's identifier.
  def name : String
    bytes = LibLLVMM.get_module_identifier(self, out bytesize)
    String.new(Slice.new(bytes, bytesize))
  end

  # Sets the module's identifier.
  def name=(name : String)
    LibLLVMM.set_module_identifier(self, name, name.bytesize)
  end

  # Sets the module's target triple.
  def target=(target)
    LibLLVMM.set_target(self, target)
  end

  # A deep copy of this module, associated with the same context.
  def clone : Module
    Module.new(LibLLVMM.clone_module(self), @context)
  end

  # The module-level inline assembly.
  def inline_asm : String
    bytes = LibLLVMM.get_module_inline_asm(self, out len)
    String.new(Slice.new(bytes, len))
  end

  # Sets the module-level inline assembly.
  def inline_asm=(assembly : String)
    LibLLVMM.set_module_inline_asm2(self, assembly, assembly.bytesize)
  end

  # Appends to the module-level inline assembly.
  def append_inline_asm(assembly : String)
    LibLLVMM.append_module_inline_asm(self, assembly, assembly.bytesize)
  end

  # The module's data layout string, or an empty string if unset.
  def data_layout_string : String
    String.new LibLLVMM.get_data_layout_str(self)
  end

  # Sets the module's data layout from a layout string.
  def data_layout_string=(layout : String)
    LibLLVMM.set_data_layout(self, layout)
  end

  # Sets the module's data layout from a `TargetData`.
  def data_layout=(data : TargetData)
    LibLLVMM.set_module_data_layout(self, data)
  end

  # Prints the module's IR to stderr (for debugging).
  def dump
    LibLLVMM.dump_module(self)
  end

  # The module's functions.
  def functions
    FunctionCollection.new(self)
  end

  # The module's global variables.
  def globals
    GlobalCollection.new(self)
  end

  # Adds a module flag with an `i32` value, e.g.
  # `add_flag(:error, "Debug Info Version", LLVMM::DEBUG_METADATA_VERSION)`.
  def add_flag(module_flag : LibLLVMM::ModuleFlagBehavior, key : String, val : Int32)
    add_flag(module_flag, key, @context.int32.const_int(val))
  end

  # Adds a module flag with an arbitrary constant value.
  def add_flag(module_flag : LibLLVMM::ModuleFlagBehavior, key : String, val : Value)
    LibLLVMM.add_module_flag(
      self,
      module_flag,
      key,
      key.bytesize,
      LibLLVMM.value_as_metadata(val.to_unsafe)
    )
  end

  # All module flags as `{behavior, key, metadata}` tuples.
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

  # The metadata of the module flag *key*, or `nil` if there is no such flag.
  def module_flag(key : String) : Metadata?
    md = LibLLVMM.get_module_flag(self, key, key.bytesize)
    md.null? ? nil : Metadata.new(md, @context)
  end

  # The module's named metadata nodes.
  def named_metadata : NamedMetadataCollection
    NamedMetadataCollection.new(self)
  end

  # Adds a global alias *name* for *aliasee* in the given address space.
  def add_global_alias(type : Type, aliasee, name : String, address_space = 0) : Value
    Value.new LibLLVMM.add_alias2(self, type, address_space, aliasee, name)
  end

  # The global alias named *name*, or `nil`.
  def named_global_alias(name : String) : Value?
    ga = LibLLVMM.get_named_global_alias(self, name, name.bytesize)
    ga.null? ? nil : Value.new(ga)
  end

  # Iterates over the module's global aliases.
  def each_global_alias(& : Value ->) : Nil
    ga = LibLLVMM.get_first_global_alias(self)
    until ga.null?
      yield Value.new(ga)
      ga = LibLLVMM.get_next_global_alias(ga)
    end
  end

  # Adds an indirect function (`ifunc`) *name*, resolved at load time by
  # *resolver*.
  def add_global_ifunc(name : String, type : Type, resolver, address_space = 0) : Value
    Value.new LibLLVMM.add_global_ifunc(self, name, name.bytesize, type, address_space, resolver)
  end

  # The indirect function named *name*, or `nil`.
  def named_global_ifunc(name : String) : Value?
    ifunc = LibLLVMM.get_named_global_ifunc(self, name, name.bytesize)
    ifunc.null? ? nil : Value.new(ifunc)
  end

  # Iterates over the module's indirect functions.
  def each_global_ifunc(& : Value ->) : Nil
    ifunc = LibLLVMM.get_first_global_ifunc(self)
    until ifunc.null?
      yield Value.new(ifunc)
      ifunc = LibLLVMM.get_next_global_ifunc(ifunc)
    end
  end

  # Writes the module as bitcode to *filename*. Returns LLVM's status code
  # (0 on success).
  def write_bitcode_to_file(filename : String)
    LibLLVMM.write_bitcode_to_file self, filename
  end

  # The debug metadata version recorded in the module.
  def debug_metadata_version : UInt32
    LibLLVMM.get_module_debug_metadata_version(self)
  end

  # Removes all debug info from the module; returns whether it was modified.
  def strip_debug_info : Bool
    LibLLVMM.strip_module_debug_info(self) != 0
  end

  # Serializes the module to a new `MemoryBuffer` owned by the caller.
  def write_bitcode_to_memory_buffer
    MemoryBuffer.new(LibLLVMM.write_bitcode_to_memory_buffer self)
  end

  # Writes the module as bitcode to the file descriptor *fd*; *should_close*
  # closes the descriptor after writing.
  def write_bitcode_to_fd(fd : Int, should_close = false, buffered = false)
    LibLLVMM.write_bitcode_to_fd(self, fd, should_close ? 1 : 0, buffered ? 0 : 1)
  end

  # Verifies the module; raises with the verifier's message if it is invalid.
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

  # Writes the module's textual IR to *filename*; raises on error. Returns
  # `self`.
  def print_to_file(filename)
    if LibLLVMM.print_module_to_file(self, filename, out error_msg) != 0
      raise LLVMM.string_and_dispose(error_msg)
    end
    self
  end

  # Two modules are equal if they wrap the same underlying `LLVMModule`.
  def ==(other : self)
    @unwrap == other.@unwrap
  end

  # Appends the module's textual IR to *io*.
  def to_s(io : IO) : Nil
    LLVMM.to_io(LibLLVMM.print_module_to_string(self), io)
    self
  end

  # The underlying `LibLLVMM::ModuleRef`.
  def to_unsafe
    @unwrap
  end

  # Marks the module as owned elsewhere (used when handing it to the JIT,
  # e.g. via `JITCompiler` or `Orc::ThreadSafeModule`). Yields if ownership
  # was already taken, letting the caller reject a double handoff.
  def take_ownership(&)
    if @owned
      yield
    else
      @owned = true
    end
  end
end
