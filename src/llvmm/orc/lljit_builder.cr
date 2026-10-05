# src/llvmm/orc/lljit_builder.cr
@[Experimental("The C API wrapped by this type is marked as experimental by LLVMM.")]
class LLVMM::Orc::LLJITBuilder
  protected def initialize(@unwrap : LibLLVMM::OrcLLJITBuilderRef)
    @dispose_on_finalize              = true
    @object_linking_layer_creator     = nil
    @object_linking_layer_creator_box = Pointer(Void).null
  end

  def self.new
    new(LibLLVMM.orc_create_lljit_builder)
  end

  def to_unsafe
    @unwrap
  end

  def set_object_linking_layer_creator(&creator : ExecutionSession, String -> LibLLVMM::OrcObjectLayerRef) : Nil
    @object_linking_layer_creator     = creator
    @object_linking_layer_creator_box = Box.box(creator)
    LibLLVMM.orc_lljit_builder_set_object_linking_layer_creator(self, ->(ctx : Void*, es : LibLLVMM::OrcExecutionSessionRef, triple : LibLLVMM::Char*) {
      Box(Proc(ExecutionSession, String, LibLLVMM::OrcObjectLayerRef)).unbox(ctx).call(ExecutionSession.new(es), String.new(triple))
    }, @object_linking_layer_creator_box)
  end

  def dispose : Nil
    LibLLVMM.orc_dispose_lljit_builder(self)
    @unwrap = LibLLVMM::OrcLLJITBuilderRef.null
  end

  def finalize
    if @dispose_on_finalize && @unwrap
      dispose
    end
  end

  def take_ownership(&) : Nil
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end
end
