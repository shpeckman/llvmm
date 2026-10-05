# src/llvmm/orc/jit_dylib.cr
# Wraps LLVM's ORCv2 `JITDylib`, a dynamic library inside an
# `ExecutionSession` that holds symbol definitions, a link order and
# definition generators used to resolve symbols at lookup time.
#
# Dylibs are owned by their session. Instances are obtained from
# `LLJIT#main_jit_dylib`, `ExecutionSession#[]` or
# `ExecutionSession#create_jit_dylib`; this wrapper never takes ownership.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::JITDylib
  protected def initialize(@unwrap : LibLLVMM::OrcJITDylibRef)
    @symbol_filter     = nil
    @symbol_filter_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  # Creates a new resource tracker for this dylib. The caller owns the
  # returned tracker and must call `ResourceTracker#release` on it (typically
  # after transferring or removing its resources).
  def create_resource_tracker : ResourceTracker
    ResourceTracker.new(LibLLVMM.orc_jit_dylib_create_resource_tracker(self))
  end

  # Returns the dylib's default resource tracker. The returned tracker is
  # borrowed from the dylib: calling `ResourceTracker#release` on it raises.
  def default_resource_tracker : ResourceTracker
    ResourceTracker.new(LibLLVMM.orc_jit_dylib_get_default_resource_tracker(self), owned: false)
  end

  # Removes all symbol definitions and resource trackers from the dylib.
  # Raises `LLVMM::Error` on failure.
  def clear : Nil
    LLVMM.assert LibLLVMM.orc_jit_dylib_clear(self)
  end

  # Adds *generator* to the dylib's generator list. Generators are consulted,
  # in order, when a lookup cannot be satisfied by existing definitions.
  def add_generator(generator : DefinitionGenerator) : Nil
    LibLLVMM.orc_jit_dylib_add_generator(self, generator)
  end

  # Makes symbols exported by the current process visible to JIT'd code by
  # adding a dynamic library search generator for the process. *global_prefix*
  # is the target's data-layout prefix (`LLJIT#global_prefix`, e.g. `'_'`).
  # Raises `LLVMM::Error` if the generator cannot be created.
  def link_symbols_from_current_process(global_prefix : Char) : Nil
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_process(out dg, global_prefix.ord.to_u8, nil, nil)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  # Same as `link_symbols_from_current_process(global_prefix)`, but only
  # symbols for which the *filter* block returns `true` are exposed.
  #
  # The filter is kept alive by this wrapper; it must not capture state that
  # becomes invalid before the JIT is disposed.
  def link_symbols_from_current_process(global_prefix : Char, &filter : String -> Bool) : Nil
    @symbol_filter     = filter
    @symbol_filter_box = Box.box(filter)
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_process(out dg, global_prefix.ord.to_u8, ->(ctx : Void*, sym : LibLLVMM::OrcSymbolStringPoolEntryRef) {
      name = String.new(LibLLVMM.orc_symbol_string_pool_entry_str(sym))
      Box(Proc(String, Bool)).unbox(ctx).call(name) ? 1 : 0
    }, @symbol_filter_box)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  # Makes symbols exported by the dynamic library at *path* visible to JIT'd
  # code. *global_prefix* is the target's data-layout prefix. Raises
  # `LLVMM::Error` if the library cannot be loaded.
  def link_symbols_from_path(path : String, global_prefix : Char) : Nil
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_path(out dg, path.check_no_null_byte, global_prefix.ord.to_u8, nil, nil)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  # Makes symbols from the static archive at *path* visible to JIT'd code,
  # pulling members through *obj_layer* on demand. Raises `LLVMM::Error` if the
  # archive cannot be loaded.
  #
  # Only available with LLVMM 21 and above: the LLVMM 18-20 headers declare this
  # function but the C symbol was never actually exported (upstream header/impl mismatch).
  # On those versions this method raises `NotImplementedError`.
  def link_symbols_from_static_library(path : String, obj_layer : ObjectLayer) : Nil
    {% if LibLLVMM.has_method?(:orc_create_static_library_search_generator_for_path) %}
      LLVMM.assert LibLLVMM.orc_create_static_library_search_generator_for_path(out dg, obj_layer, path.check_no_null_byte)
      LibLLVMM.orc_jit_dylib_add_generator(self, dg)
    {% else %}
      raise NotImplementedError.new("LLVMM::Orc::JITDylib#link_symbols_from_static_library")
    {% end %}
  end
end
