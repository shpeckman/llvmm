# src/llvmm/orc/jit_dylib.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::JITDylib
  protected def initialize(@unwrap : LibLLVMM::OrcJITDylibRef)
    @symbol_filter     = nil
    @symbol_filter_box = Pointer(Void).null
  end

  def to_unsafe
    @unwrap
  end

  def create_resource_tracker : ResourceTracker
    ResourceTracker.new(LibLLVMM.orc_jit_dylib_create_resource_tracker(self))
  end

  def default_resource_tracker : ResourceTracker
    ResourceTracker.new(LibLLVMM.orc_jit_dylib_get_default_resource_tracker(self), owned: false)
  end

  def clear : Nil
    LLVMM.assert LibLLVMM.orc_jit_dylib_clear(self)
  end

  def add_generator(generator : DefinitionGenerator) : Nil
    LibLLVMM.orc_jit_dylib_add_generator(self, generator)
  end

  def link_symbols_from_current_process(global_prefix : Char) : Nil
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_process(out dg, global_prefix.ord.to_u8, nil, nil)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  def link_symbols_from_current_process(global_prefix : Char, &filter : String -> Bool) : Nil
    @symbol_filter     = filter
    @symbol_filter_box = Box.box(filter)
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_process(out dg, global_prefix.ord.to_u8, ->(ctx : Void*, sym : LibLLVMM::OrcSymbolStringPoolEntryRef) {
      name = String.new(LibLLVMM.orc_symbol_string_pool_entry_str(sym))
      Box(Proc(String, Bool)).unbox(ctx).call(name) ? 1 : 0
    }, @symbol_filter_box)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  def link_symbols_from_path(path : String, global_prefix : Char) : Nil
    LLVMM.assert LibLLVMM.orc_create_dynamic_library_search_generator_for_path(out dg, path.check_no_null_byte, global_prefix.ord.to_u8, nil, nil)
    LibLLVMM.orc_jit_dylib_add_generator(self, dg)
  end

  # Only available with LLVMM 21 and above: the LLVMM 18-20 headers declare this
  # function but the C symbol was never actually exported (upstream header/impl mismatch).
  def link_symbols_from_static_library(path : String, obj_layer : ObjectLayer) : Nil
    {% if LibLLVMM.has_method?(:orc_create_static_library_search_generator_for_path) %}
      LLVMM.assert LibLLVMM.orc_create_static_library_search_generator_for_path(out dg, obj_layer, path.check_no_null_byte)
      LibLLVMM.orc_jit_dylib_add_generator(self, dg)
    {% else %}
      raise NotImplementedError.new("LLVMM::Orc::JITDylib#link_symbols_from_static_library")
    {% end %}
  end
end
