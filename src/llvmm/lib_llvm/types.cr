# src/llvmm/lib_llvm/types.cr
lib LibLLVMM
  # LLVMBool
  alias Bool = LibC::Int

  type MemoryBufferRef = Void*
  type ContextRef = Void*
  type ModuleRef = Void*
  type TypeRef = Void*
  type ValueRef = Void*
  type UseRef = Void*
  type BasicBlockRef = Void*
  type MetadataRef = Void*
  type BuilderRef = Void*
  type DIBuilderRef = Void*
  type PassManagerRef = Void*
  type OperandBundleRef = Void*
  type AttributeRef = Void*
  type DbgRecordRef = Void*
  type DiagnosticInfoRef = Void*
  type ValueMetadataEntryRef = Void*
  type NamedMDNodeRef = Void*
  type ModuleFlagEntriesRef = Void*
end
