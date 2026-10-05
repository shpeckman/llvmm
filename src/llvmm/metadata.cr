# src/llvmm/metadata.cr
require "./lib_llvm"

# An LLVM metadata node (wraps `LLVMMetadataRef`), tagged with the `Context`
# it belongs to.
#
# Metadata is owned by its context/module; this struct only holds a reference
# and never disposes the node, except for `dispose_temporary`, which releases
# a temporary node on request. The accessors cover debug-info (DI) nodes and
# are only valid for metadata of the corresponding kind (e.g. `size_in_bits`
# on a DIType node, `filename` on a DIFile node); use `kind`/`di_node_tag` to
# check before calling them.
struct LLVMM::Metadata
  # The context this node belongs to.
  getter context : Context

  def initialize(@unwrap : LibLLVMM::MetadataRef, @context : Context)
  end

  # Whether the underlying LLVM reference is null.
  def null? : Bool
    @unwrap.null?
  end

  # Two nodes are equal when they wrap the same underlying LLVM node.
  def ==(other : self)
    @unwrap == other.@unwrap
  end

  # The kind of this metadata node.
  def kind : MetadataKind
    LibLLVMM.get_metadata_kind(self)
  end

  # The DWARF tag of this debug-info node.
  def di_node_tag : UInt16
    LibLLVMM.get_di_node_tag(self)
  end

  # The name of a DIType node.
  def name : String
    ptr = LibLLVMM.di_type_get_name(self, out len)
    String.new(ptr, len)
  end

  # The size in bits of a DIType node.
  def size_in_bits : UInt64
    LibLLVMM.di_type_get_size_in_bits(self)
  end

  # The alignment in bits of a DIType node.
  def align_in_bits : UInt32
    LibLLVMM.di_type_get_align_in_bits(self)
  end

  # The offset in bits of a DIType node (e.g. a member inside a composite
  # type).
  def offset_in_bits : UInt64
    LibLLVMM.di_type_get_offset_in_bits(self)
  end

  # The source line of a DIType node.
  def type_line : UInt32
    LibLLVMM.di_type_get_line(self)
  end

  # The flags of a DIType node.
  def flags : DIFlags
    LibLLVMM.di_type_get_flags(self)
  end

  # The filename of a DIFile node.
  def filename : String
    ptr = LibLLVMM.di_file_get_filename(self, out len)
    String.new(ptr, len)
  end

  # The directory of a DIFile node.
  def directory : String
    ptr = LibLLVMM.di_file_get_directory(self, out len)
    String.new(ptr, len)
  end

  # The optional embedded source text of a DIFile node (empty when none was
  # attached).
  def file_source : String
    ptr = LibLLVMM.di_file_get_source(self, out len)
    String.new(ptr, len)
  end

  # The line of a DILocation node.
  def location_line : UInt32
    LibLLVMM.di_location_get_line(self)
  end

  # The column of a DILocation node.
  def location_column : UInt32
    LibLLVMM.di_location_get_column(self)
  end

  # The scope of a DILocation node.
  def location_scope : Metadata
    Metadata.new(LibLLVMM.di_location_get_scope(self), @context)
  end

  # The location this DILocation was inlined at, or `nil` when it is not an
  # inlined location.
  def location_inlined_at : Metadata?
    md = LibLLVMM.di_location_get_inlined_at(self)
    md.null? ? nil : Metadata.new(md, @context)
  end

  # The file of a DIScope node.
  def scope_file : Metadata
    Metadata.new(LibLLVMM.di_scope_get_file(self), @context)
  end

  # The file of a DIVariable node.
  def variable_file : Metadata
    Metadata.new(LibLLVMM.di_variable_get_file(self), @context)
  end

  # The scope of a DIVariable node.
  def variable_scope : Metadata
    Metadata.new(LibLLVMM.di_variable_get_scope(self), @context)
  end

  # The line of a DIVariable node.
  def variable_line : UInt32
    LibLLVMM.di_variable_get_line(self)
  end

  # The line of a DISubprogram node.
  def subprogram_line : UInt32
    LibLLVMM.di_subprogram_get_line(self)
  end

  # The DIVariable of a DIGlobalVariableExpression node.
  def gve_variable : Metadata
    Metadata.new(LibLLVMM.di_global_variable_expression_get_variable(self), @context)
  end

  # The DIExpression of a DIGlobalVariableExpression node.
  def gve_expression : Metadata
    Metadata.new(LibLLVMM.di_global_variable_expression_get_expression(self), @context)
  end

  # Disposes a temporary metadata node (e.g. one created via
  # `Context#temporary_md_node`). Temporary nodes must be disposed after they
  # have been replaced with their permanent counterparts; calling this on a
  # non-temporary node is invalid.
  def dispose_temporary : Nil
    LibLLVMM.dispose_temporary_md_node(self)
  end

  def to_unsafe
    @unwrap
  end
end
