# src/llvmm/orc/definition_generator.cr
# Wraps LLVM's ORCv2 `DefinitionGenerator`: a fallback consulted during symbol
# lookup that can synthesize definitions for symbols not otherwise found.
#
# No finalizer is installed. Call `#dispose` explicitly, unless the generator
# was added to a `JITDylib` via `JITDylib#add_generator`, which takes ownership —
# disposing it afterwards is an error.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::DefinitionGenerator
  protected def initialize(@unwrap : LibLLVMM::OrcDefinitionGeneratorRef)
  end

  # Creates a generator from a raw C try-to-generate callback (see LLVM's
  # `LLVMOrcCreateCustomCAPIDefinitionGenerator`). *ctx* is an opaque pointer
  # passed back to the callback on each invocation.
  def self.custom(try_to_generate : LibLLVMM::OrcCAPIDefinitionGeneratorTryToGenerateFunction, ctx : Void* = Pointer(Void).null) : self
    new(LibLLVMM.orc_create_custom_capi_definition_generator(try_to_generate, ctx, nil))
  end

  def to_unsafe
    @unwrap
  end

  # Releases the generator. Safe to call more than once. Must not be called
  # once the generator has been added to a `JITDylib`.
  def dispose : Nil
    return if @unwrap.null?
    LibLLVMM.orc_dispose_definition_generator(to_unsafe)
    @unwrap = LibLLVMM::OrcDefinitionGeneratorRef.null
  end
end
