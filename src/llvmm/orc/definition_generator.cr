# src/llvmm/orc/definition_generator.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::DefinitionGenerator
  protected def initialize(@unwrap : LibLLVMM::OrcDefinitionGeneratorRef)
  end

  def self.custom(try_to_generate : LibLLVMM::OrcCAPIDefinitionGeneratorTryToGenerateFunction, ctx : Void* = Pointer(Void).null) : self
    new(LibLLVMM.orc_create_custom_capi_definition_generator(try_to_generate, ctx, nil))
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    return if @unwrap.null?
    LibLLVMM.orc_dispose_definition_generator(to_unsafe)
    @unwrap = LibLLVMM::OrcDefinitionGeneratorRef.null
  end
end
