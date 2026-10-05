# src/llvmm/metadata.cr
require "./lib_llvm"

struct LLVMM::Metadata
  getter context : Context

  def initialize(@unwrap : LibLLVMM::MetadataRef, @context : Context)
  end

  def null? : Bool
    @unwrap.null?
  end

  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def kind : MetadataKind
    LibLLVMM.get_metadata_kind(self)
  end

  def di_node_tag : UInt16
    LibLLVMM.get_di_node_tag(self)
  end

  def name : String
    ptr = LibLLVMM.di_type_get_name(self, out len)
    String.new(ptr, len)
  end

  def size_in_bits : UInt64
    LibLLVMM.di_type_get_size_in_bits(self)
  end

  def align_in_bits : UInt32
    LibLLVMM.di_type_get_align_in_bits(self)
  end

  def offset_in_bits : UInt64
    LibLLVMM.di_type_get_offset_in_bits(self)
  end

  def type_line : UInt32
    LibLLVMM.di_type_get_line(self)
  end

  def flags : DIFlags
    LibLLVMM.di_type_get_flags(self)
  end

  def filename : String
    ptr = LibLLVMM.di_file_get_filename(self, out len)
    String.new(ptr, len)
  end

  def directory : String
    ptr = LibLLVMM.di_file_get_directory(self, out len)
    String.new(ptr, len)
  end

  def file_source : String
    ptr = LibLLVMM.di_file_get_source(self, out len)
    String.new(ptr, len)
  end

  def location_line : UInt32
    LibLLVMM.di_location_get_line(self)
  end

  def location_column : UInt32
    LibLLVMM.di_location_get_column(self)
  end

  def location_scope : Metadata
    Metadata.new(LibLLVMM.di_location_get_scope(self), @context)
  end

  def location_inlined_at : Metadata?
    md = LibLLVMM.di_location_get_inlined_at(self)
    md.null? ? nil : Metadata.new(md, @context)
  end

  def scope_file : Metadata
    Metadata.new(LibLLVMM.di_scope_get_file(self), @context)
  end

  def variable_file : Metadata
    Metadata.new(LibLLVMM.di_variable_get_file(self), @context)
  end

  def variable_scope : Metadata
    Metadata.new(LibLLVMM.di_variable_get_scope(self), @context)
  end

  def variable_line : UInt32
    LibLLVMM.di_variable_get_line(self)
  end

  def subprogram_line : UInt32
    LibLLVMM.di_subprogram_get_line(self)
  end

  def gve_variable : Metadata
    Metadata.new(LibLLVMM.di_global_variable_expression_get_variable(self), @context)
  end

  def gve_expression : Metadata
    Metadata.new(LibLLVMM.di_global_variable_expression_get_expression(self), @context)
  end

  def dispose_temporary : Nil
    LibLLVMM.dispose_temporary_md_node(self)
  end

  def to_unsafe
    @unwrap
  end
end
