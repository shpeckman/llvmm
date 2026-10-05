# src/llvmm/lib_llvm/object.cr
lib LibLLVMM
  alias BinaryRef = Void*
  alias SectionIteratorRef = Void*
  alias SymbolIteratorRef = Void*
  alias RelocationIteratorRef = Void*

  fun create_binary = LLVMCreateBinary(mem_buf : MemoryBufferRef, context : ContextRef, error_message : Char**) : BinaryRef
  fun dispose_binary = LLVMDisposeBinary(br : BinaryRef)

  fun object_file_copy_section_iterator = LLVMObjectFileCopySectionIterator(br : BinaryRef) : SectionIteratorRef
  fun object_file_is_section_iterator_at_end = LLVMObjectFileIsSectionIteratorAtEnd(br : BinaryRef, si : SectionIteratorRef) : Bool
  fun object_file_copy_symbol_iterator = LLVMObjectFileCopySymbolIterator(br : BinaryRef) : SymbolIteratorRef
  fun object_file_is_symbol_iterator_at_end = LLVMObjectFileIsSymbolIteratorAtEnd(br : BinaryRef, si : SymbolIteratorRef) : Bool
  fun dispose_section_iterator = LLVMDisposeSectionIterator(si : SectionIteratorRef)
  fun dispose_symbol_iterator = LLVMDisposeSymbolIterator(si : SymbolIteratorRef)
  fun dispose_relocation_iterator = LLVMDisposeRelocationIterator(ri : RelocationIteratorRef)
  fun move_to_next_section = LLVMMoveToNextSection(si : SectionIteratorRef)
  fun move_to_next_symbol = LLVMMoveToNextSymbol(si : SymbolIteratorRef)
  fun move_to_next_relocation = LLVMMoveToNextRelocation(ri : RelocationIteratorRef)

  fun get_section_name = LLVMGetSectionName(si : SectionIteratorRef) : Char*
  fun get_section_size = LLVMGetSectionSize(si : SectionIteratorRef) : UInt64
  fun get_section_contents = LLVMGetSectionContents(si : SectionIteratorRef) : Char*
  fun get_section_address = LLVMGetSectionAddress(si : SectionIteratorRef) : UInt64

  fun get_relocations = LLVMGetRelocations(section : SectionIteratorRef) : RelocationIteratorRef
  fun is_relocation_iterator_at_end = LLVMIsRelocationIteratorAtEnd(section : SectionIteratorRef, ri : RelocationIteratorRef) : Bool

  fun get_symbol_name = LLVMGetSymbolName(si : SymbolIteratorRef) : Char*
  fun get_symbol_address = LLVMGetSymbolAddress(si : SymbolIteratorRef) : UInt64
  fun get_symbol_size = LLVMGetSymbolSize(si : SymbolIteratorRef) : UInt64

  fun get_relocation_offset = LLVMGetRelocationOffset(ri : RelocationIteratorRef) : UInt64
  fun get_relocation_symbol = LLVMGetRelocationSymbol(ri : RelocationIteratorRef) : SymbolIteratorRef
  fun get_relocation_type = LLVMGetRelocationType(ri : RelocationIteratorRef) : UInt64
  fun get_relocation_type_name = LLVMGetRelocationTypeName(ri : RelocationIteratorRef) : Char*
  fun get_relocation_value_string = LLVMGetRelocationValueString(ri : RelocationIteratorRef) : Char*
end
