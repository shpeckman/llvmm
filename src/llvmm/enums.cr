# src/llvmm/enums.cr
module LLVMM
  # LLVM attribute kinds for functions, return values and parameters,
  # combinable as a flag set.
  #
  # Members are mapped to LLVM's runtime attribute kind ids lazily on first
  # use. A few attributes (see `requires_type?`) also carry a `Type`.
  #
  # ```
  # call.add_instruction_attribute(
  #   LLVMM::AttributeIndex::FunctionIndex.value,
  #   LLVMM::Attribute::NoUnwind,
  #   context)
  # ```
  @[Flags]
  enum Attribute : UInt64
    Alignment
    AllocSize
    AlwaysInline
    ArgMemOnly
    Builtin
    ByVal
    Cold
    Convergent
    Dereferenceable
    DereferenceableOrNull
    InAlloca
    InReg
    InaccessibleMemOnly
    InaccessibleMemOrArgMemOnly
    InlineHint
    JumpTable
    MinSize
    Naked
    Nest
    NoAlias
    NoBuiltin
    NoCapture
    NoDuplicate
    NoFree
    NoImplicitFloat
    NoInline
    NoRecurse
    NoRedZone
    NoReturn
    NoSync
    NoUnwind
    NonLazyBind
    NonNull
    OptimizeForSize
    OptimizeNone
    ReadNone
    ReadOnly
    Returned
    ImmArg
    ReturnsTwice
    SExt
    SafeStack
    SanitizeAddress
    SanitizeMemory
    SanitizeThread
    StackAlignment
    StackProtect
    StackProtectReq
    StackProtectStrong
    StructRet
    SwiftError
    SwiftSelf
    UWTable
    WillReturn
    WriteOnly
    ZExt
    Captures

    # NOTE: enum body does not allow `class_getter` or `TypeDeclaration`, hence
    # the nil cast
    @@kind_ids = nil.as(Hash(Attribute, UInt32)?)

    protected def self.kind_ids
      @@kind_ids ||= load_llvm_kinds_from_names
    end

    @@typed_attrs = nil.as(Array(Attribute)?)

    private def self.typed_attrs
      @@typed_attrs ||= load_llvm_typed_attributes
    end

    # Yields the LLVM attribute kind id of each member in this set.
    def each_kind(& : UInt32 ->)
      kind_ids = Attribute.kind_ids
      each do |member|
        yield kind_ids[member]
      end
    end

    private def self.kind_for_name(name : String)
      LibLLVMM.get_enum_attribute_kind_for_name(name, name.bytesize)
    end

    private def self.load_llvm_kinds_from_names
      kinds = {} of Attribute => UInt32
      kinds[Alignment] = kind_for_name("align")
      kinds[AllocSize] = kind_for_name("allocsize")
      kinds[AlwaysInline] = kind_for_name("alwaysinline")
      kinds[ArgMemOnly] = kind_for_name("argmemonly")
      kinds[Builtin] = kind_for_name("builtin")
      kinds[ByVal] = kind_for_name("byval")
      kinds[Captures] = kind_for_name("captures")
      kinds[Cold] = kind_for_name("cold")
      kinds[Convergent] = kind_for_name("convergent")
      kinds[Dereferenceable] = kind_for_name("dereferenceable")
      kinds[DereferenceableOrNull] = kind_for_name("dereferenceable_or_null")
      kinds[InAlloca] = kind_for_name("inalloca")
      kinds[InReg] = kind_for_name("inreg")
      kinds[InaccessibleMemOnly] = kind_for_name("inaccessiblememonly")
      kinds[InaccessibleMemOrArgMemOnly] = kind_for_name("inaccessiblemem_or_argmemonly")
      kinds[InlineHint] = kind_for_name("inlinehint")
      kinds[JumpTable] = kind_for_name("jumptable")
      kinds[MinSize] = kind_for_name("minsize")
      kinds[Naked] = kind_for_name("naked")
      kinds[Nest] = kind_for_name("nest")
      kinds[NoAlias] = kind_for_name("noalias")
      kinds[NoBuiltin] = kind_for_name("nobuiltin")
      kinds[NoCapture] = kind_for_name("nocapture")
      kinds[NoDuplicate] = kind_for_name("noduplicate")
      kinds[NoFree] = kind_for_name("nofree")
      kinds[NoImplicitFloat] = kind_for_name("noimplicitfloat")
      kinds[NoInline] = kind_for_name("noinline")
      kinds[NoRecurse] = kind_for_name("norecurse")
      kinds[NoRedZone] = kind_for_name("noredzone")
      kinds[NoReturn] = kind_for_name("noreturn")
      kinds[NoSync] = kind_for_name("nosync")
      kinds[NoUnwind] = kind_for_name("nounwind")
      kinds[NonLazyBind] = kind_for_name("nonlazybind")
      kinds[NonNull] = kind_for_name("nonnull")
      kinds[OptimizeForSize] = kind_for_name("optsize")
      kinds[OptimizeNone] = kind_for_name("optnone")
      kinds[ReadNone] = kind_for_name("readnone")
      kinds[ReadOnly] = kind_for_name("readonly")
      kinds[Returned] = kind_for_name("returned")
      kinds[ImmArg] = kind_for_name("immarg")
      kinds[ReturnsTwice] = kind_for_name("returns_twice")
      kinds[SExt] = kind_for_name("signext")
      kinds[SafeStack] = kind_for_name("safestack")
      kinds[SanitizeAddress] = kind_for_name("sanitize_address")
      kinds[SanitizeMemory] = kind_for_name("sanitize_memory")
      kinds[SanitizeThread] = kind_for_name("sanitize_thread")
      kinds[StackAlignment] = kind_for_name("alignstack")
      kinds[StackProtect] = kind_for_name("ssp")
      kinds[StackProtectReq] = kind_for_name("sspreq")
      kinds[StackProtectStrong] = kind_for_name("sspstrong")
      kinds[StructRet] = kind_for_name("sret")
      kinds[SwiftError] = kind_for_name("swifterror")
      kinds[SwiftSelf] = kind_for_name("swiftself")
      kinds[UWTable] = kind_for_name("uwtable")
      kinds[WillReturn] = kind_for_name("willreturn")
      kinds[WriteOnly] = kind_for_name("writeonly")
      kinds[ZExt] = kind_for_name("zeroext")
      kinds
    end

    private def self.load_llvm_typed_attributes
      typed_attrs = [] of Attribute

      typed_attrs << ByVal
      typed_attrs << StructRet
      typed_attrs << InAlloca

      typed_attrs
    end

    # The LLVM attribute kind id for *member*.
    def self.kind_for(member)
      kind_ids[member]
    end

    # The member for LLVM attribute kind id *kind*.
    #
    # Raises if *kind* does not correspond to a known member.
    def self.from_kind(kind)
      kind_ids.key_for(kind)
    end

    # Whether the attribute with LLVM kind id *kind* requires a `Type`
    # argument (currently `ByVal`, `StructRet` and `InAlloca`).
    def self.requires_type?(kind)
      member = from_kind(kind)
      typed_attrs.includes?(member)
    end
  end

  # Well-known attribute indices: `ReturnIndex` (0) and `FunctionIndex`
  # (~0). Parameter attributes use indices 1..N.
  enum AttributeIndex : UInt32
    ReturnIndex   = 0_u32
    FunctionIndex = ~0_u32
  end

  # Linkage types for global values (functions, global variables, aliases).
  enum Linkage
    External
    AvailableExternally
    LinkOnceAny
    LinkOnceODR
    LinkOnceODRAutoHide
    WeakAny
    WeakODR
    Appending
    Internal
    Private
    DLLImport # obsolete
    DLLExport # obsolete
    ExternalWeak
    Ghost
    Common
    LinkerPrivate
    LinkerPrivateWeak
  end

  # DLL storage class for global values on Windows targets.
  enum DLLStorageClass
    Default

    # Function to be imported from DLL.
    DLLImport

    # Function to be accessible from DLL.
    DLLExport
  end

  # Symbol visibility styles for global values.
  enum Visibility
    Default
    Hidden
    Protected
  end

  # Whether the address of a global value is significant
  # (`unnamed_addr`/`local_unnamed_addr`).
  enum UnnamedAddress
    None
    Local
    Global
  end

  # Thread-local storage models for thread-local globals.
  enum ThreadLocalMode
    NotThreadLocal
    GeneralDynamicTLS
    LocalDynamicTLS
    InitialExecTLS
    LocalExecTLS
  end

  # Integer comparison predicates for `icmp` (values match LLVM's
  # `LLVMIntPredicate`).
  enum IntPredicate
    EQ  = 32
    NE
    UGT
    UGE
    ULT
    ULE
    SGT
    SGE
    SLT
    SLE
  end

  # Floating-point comparison predicates for `fcmp` (values match LLVM's
  # `LLVMRealPredicate`).
  enum RealPredicate
    PredicateFalse
    OEQ
    OGT
    OGE
    OLT
    OLE
    ONE
    ORD
    UNO
    UEQ
    UGT
    UGE
    ULT
    ULE
    UNE
    PredicateTrue
  end

  # LLVM instruction opcodes (values match LLVM's `LLVMOpcode`).
  #
  # Some members are version-gated: `Br` exists only before LLVM 23, while
  # `UncondBr`/`CondBr` require LLVM 23+; `PtrToAddr` requires LLVM 22+.
  enum Opcode
    Ret = 1
    {% if LibLLVMM::IS_LT_230 %}
      Br = 2
    {% else %}
      UncondBr = 70
      CondBr   = 71
    {% end %}
    Switch        =  3
    IndirectBr    =  4
    Invoke        =  5
    Unreachable   =  7
    CallBr        = 67
    FNeg          = 66
    Add           =  8
    FAdd          =  9
    Sub           = 10
    FSub          = 11
    Mul           = 12
    FMul          = 13
    UDiv          = 14
    SDiv          = 15
    FDiv          = 16
    URem          = 17
    SRem          = 18
    FRem          = 19
    Shl           = 20
    LShr          = 21
    AShr          = 22
    And           = 23
    Or            = 24
    Xor           = 25
    Alloca        = 26
    Load          = 27
    Store         = 28
    GetElementPtr = 29
    Trunc         = 30
    ZExt          = 31
    SExt          = 32
    FPToUI        = 33
    FPToSI        = 34
    UIToFP        = 35
    SIToFP        = 36
    FPTrunc       = 37
    FPExt         = 38
    PtrToInt      = 39
    IntToPtr      = 40
    BitCast       = 41
    AddrSpaceCast = 60
    {% unless LibLLVMM::IS_LT_220 %}
      PtrToAddr = 69
    {% end %}
    ICmp           = 42
    FCmp           = 43
    PHI            = 44
    Call           = 45
    Select         = 46
    UserOp1        = 47
    UserOp2        = 48
    VAArg          = 49
    ExtractElement = 50
    InsertElement  = 51
    ShuffleVector  = 52
    ExtractValue   = 53
    InsertValue    = 54
    Freeze         = 68
    Fence          = 55
    AtomicCmpXchg  = 56
    AtomicRMW      = 57
    Resume         = 58
    LandingPad     = 59
    CleanupRet     = 61
    CatchRet       = 62
    CatchPad       = 63
    CleanupPad     = 64
    CatchSwitch    = 65
  end

  struct Type
    # Discriminator for `LLVMM::Type`, returned by `Type#kind`.
    #
    # `Byte` requires LLVM 23+.
    enum Kind
      Void
      Half
      Float
      Double
      X86_FP80
      FP128
      PPC_FP128
      Label
      Integer
      Function
      Struct
      Array
      Pointer
      Vector
      Metadata
      X86_MMX # deleted in LLVMM 20
      Token
      ScalableVector
      BFloat
      X86_AMX
      TargetExt
      {% unless LibLLVMM::IS_LT_230 %}
        Byte
      {% end %}
    end
  end

  # Code generation optimization levels for target machines.
  enum CodeGenOptLevel
    None
    Less
    Default
    Aggressive
  end

  # Output kind of target machine emission (assembly text or object file).
  enum CodeGenFileType
    AssemblyFile
    ObjectFile
  end

  # Relocation models for code generation.
  enum RelocMode
    Default
    Static
    PIC
    DynamicNoPIC
  end

  # Code models for code generation and JIT.
  enum CodeModel
    Default
    JITDefault
    Tiny
    Small
    Kernel
    Medium
    Large
  end

  # Action taken by the module verifier when verification fails.
  enum VerifierFailureAction
    AbortProcessAction # verifier will print to stderr and abort()
    PrintMessageAction # verifier will print to stderr and return 1
    ReturnStatusAction # verifier will just return 1
  end

  # Calling conventions (values match LLVM's `LLVMCallConv`).
  enum CallConvention
    C            =  0
    Fast         =  8
    Cold         =  9
    WebKit_JS    = 12
    AnyReg       = 13
    X86_StdCall  = 64
    X86_FastCall = 65
  end

  # DWARF tags used by `DIBuilder`.
  enum DwarfTag
    AutoVariable = 0x100
  end

  # DWARF type encodings used by `DIBuilder`.
  enum DwarfTypeEncoding
    Address        = 0x01
    Boolean        = 0x02
    ComplexFloat   = 0x03
    Float          = 0x04
    Signed         = 0x05
    SignedChar     = 0x06
    Unsigned       = 0x07
    UnsignedChar   = 0x08
    ImaginaryFloat = 0x09
    PackedDecimal  = 0x0a
    NumericString  = 0x0b
    Edited         = 0x0c
    SignedFixed    = 0x0d
    UnsignedFixed  = 0x0e
    DecimalFloat   = 0x0f
    Utf            = 0x10
    LoUser         = 0x80
    HiUser         = 0xff
  end

  # DWARF source language constants used by `DIBuilder`.
  enum DwarfSourceLanguage
    C89
    C
    Ada83
    C_plus_plus
    Cobol74
    Cobol85
    Fortran77
    Fortran90
    Pascal83
    Modula2

    # New in DWARF v3:

    Java
    C99
    Ada95
    Fortran95
    PLI
    ObjC
    ObjC_plus_plus
    UPC
    D

    # New in DWARF v4:

    Python

    # New in DWARF v5:

    OpenCL
    Go
    Modula3
    Haskell
    C_plus_plus_03
    C_plus_plus_11
    OCaml
    Rust
    C11
    Swift
    Julia
    Dylan
    C_plus_plus_14
    Fortran03
    Fortran08
    RenderScript
    BLISS

    Kotlin
    Zig
    Crystal
    C_plus_plus_17
    C_plus_plus_20
    C17
    Fortran18
    Ada2005
    Ada2012

    # Vendor extensions:

    Mips_Assembler
    GOOGLE_RenderScript
    BORLAND_Delphi
  end

  # Debug info flags attached to DI nodes (values match LLVM's
  # `LLVMDIFlags`).
  enum DIFlags : UInt32
    Zero       = 0
    Private    = 1
    Protected  = 2
    Public     = 3
    FwdDecl    = 1 << 2
    AppleBlock = 1 << 3

    ReservedBit4 = 1 << 4

    Virtual             = 1 << 5
    Artificial          = 1 << 6
    Explicit            = 1 << 7
    Prototyped          = 1 << 8
    ObjcClassComplete   = 1 << 9
    ObjectPointer       = 1 << 10
    Vector              = 1 << 11
    StaticMember        = 1 << 12
    LValueReference     = 1 << 13
    RValueReference     = 1 << 14
    ExternalTypeRef     = 1 << 15
    SingleInheritance   = 1 << 16
    MultipleInheritance = 2 << 16
    VirtualInheritance  = 3 << 16
    IntroducedVirtual   = 1 << 18
    BitField            = 1 << 19
    NoReturn            = 1 << 20

    PassByValue         = 1 << 22
    TypePassByReference = 1 << 23
    EnumClass           = 1 << 24
    Thunk               = 1 << 25

    NonTrivial = 1 << 26

    BigEndian    = 1 << 27
    LittleEndian = 1 << 28
  end

  # Inline assembly dialects for `Type#inline_asm`.
  enum InlineAsmDialect
    ATT
    Intel
  end

  struct Value
    # Discriminator for `LLVMM::Value`, returned by `ValueMethods#kind`.
    #
    # `ConstantByte` requires LLVM 23+; `ConstantPtrAuth` requires LLVM 19+.
    enum Kind
      Argument
      BasicBlock
      MemoryUse
      MemoryDef
      MemoryPhi

      Function
      GlobalAlias
      GlobalIFunc
      GlobalVariable
      BlockAddress
      ConstantExpr
      ConstantArray
      ConstantStruct
      ConstantVector

      UndefValue
      ConstantAggregateZero
      ConstantDataArray
      ConstantDataVector
      {% unless LibLLVMM::IS_LT_230 %}
        ConstantByte
      {% end %}
      ConstantInt
      ConstantFP
      ConstantPointerNull
      ConstantTokenNone

      MetadataAsValue
      InlineAsm

      Instruction
      PoisonValue
      ConstantTargetNone
      {% unless LibLLVMM::IS_LT_190 %}
        ConstantPtrAuth
      {% end %}
    end
  end

  struct Metadata
    # Well-known metadata kind ids (e.g. `dbg`, `tbaa`), usable wherever a
    # metadata kind id is expected (`ValueMethods#metadata`,
    # `ValueMethods#set_metadata`, ...).
    enum Type : UInt32
      Dbg                   =  0 # "dbg"
      Tbaa                  =  1 # "tbaa"
      Prof                  =  2 # "prof"
      Fpmath                =  3 # "fpmath"
      Range                 =  4 # "range"
      TbaaStruct            =  5 # "tbaa.struct"
      InvariantLoad         =  6 # "invariant.load"
      AliasScope            =  7 # "alias.scope"
      Noalias               =  8 # "noalias"
      Nontemporal           =  9 # "nontemporal"
      MemParallelLoopAccess = 10 # "llvm.mem.parallel_loop_access"
      Nonnull               = 11 # "nonnull"
      Dereferenceable       = 12 # "dereferenceable"
      DereferenceableOrNull = 13 # "dereferenceable_or_null"
      MakeImplicit          = 14 # "make.implicit"
      Unpredictable         = 15 # "unpredictable"
      InvariantGroup        = 16 # "invariant.group"
      Align                 = 17 # "align"
      Loop                  = 18 # "llvm.loop"
      Type                  = 19 # "type"
      SectionPrefix         = 20 # "section_prefix"
      AbsoluteSymbol        = 21 # "absolute_symbol"
      Associated            = 22 # "associated"
      Callees               = 23 # "callees"
      IrrLoop               = 24 # "irr_loop"
      AccessGroup           = 25 # "llvm.access.group"
      Callback              = 26 # "callback"
      PreserveAccessIndex   = 27 # "llvm.preserve.*.access.index"
    end
  end

  # Unwind table kinds for the `uwtable` function attribute.
  enum UWTableKind
    None    = 0 # No unwind table requested
    Sync    = 1 # "Synchronous" unwind tables
    Async   = 2 # "Asynchronous" unwind tables (instr precise)
    Default = 2
  end

  # No-wrap flags for getelementptr, combining `inbounds`, `nusw` and
  # `nuw`.
  @[Flags]
  enum GEPNoWrapFlags : UInt32
    InBounds = 1 << 0
    NUSW     = 1 << 1
    NUW      = 1 << 2
  end

  # Tail call kinds for call instructions.
  enum TailCallKind
    None     = 0
    Tail     = 1
    MustTail = 2
    NoTail   = 3
  end

  # Fast-math flags for floating-point instructions.
  @[Flags]
  enum FastMathFlags : UInt32
    AllowReassoc    = 1 << 0
    NoNaNs          = 1 << 1
    NoInfs          = 1 << 2
    NoSignedZeros   = 1 << 3
    AllowReciprocal = 1 << 4
    AllowContract   = 1 << 5
    ApproxFunc      = 1 << 6
  end

  # Kinds of debug records (new debug info format).
  enum DbgRecordKind
    Declare = 0
    Value   = 1
    Assign  = 2
  end

  # Checksum algorithms for debug info file checksums.
  enum ChecksumKind
    MD5    = 0
    SHA1   = 1
    SHA256 = 2
  end

  # DWARF macinfo record types.
  enum DWARFMacinfoRecordType
    Define    = 0x01
    Macro     = 0x02
    StartFile = 0x03
    EndFile   = 0x04
    VendorExt = 0xff
  end

  # Metadata node subclass ids (values match LLVM's `LLVMMetadataKind`).
  #
  # `DISubrangeType` and `DIFixedPointType` require LLVM 21+.
  enum MetadataKind : UInt32
    MDString
    ConstantAsMetadata
    LocalAsMetadata
    DistinctMDOperandPlaceholder
    MDTuple
    DILocation
    DIExpression
    DIGlobalVariableExpression
    GenericDINode
    DISubrange
    DIEnumerator
    DIBasicType
    DIDerivedType
    DICompositeType
    DISubroutineType
    DIFile
    DICompileUnit
    DISubprogram
    DILexicalBlock
    DILexicalBlockFile
    DINamespace
    DIModule
    DITemplateTypeParameter
    DITemplateValueParameter
    DIGlobalVariable
    DILocalVariable
    DILabel
    DIObjCProperty
    DIImportedEntity
    DIMacro
    DIMacroFile
    DICommonBlock
    DIStringType
    DIGenericSubrange
    DIArgList
    DIAssignID
    {% unless LibLLVMM::IS_LT_210 %}
      DISubrangeType
      DIFixedPointType
    {% end %}
  end

  # Denormal floating-point handling modes.
  enum DenormalModeKind
    IEEE         = 0
    PreserveSign = 1
    PositiveZero = 2
    Dynamic      = 3
  end

  # Severity levels of LLVM diagnostics.
  enum DiagnosticSeverity
    Error
    Warning
    Remark
    Note
  end

  # GlobalISel fallback behavior of a target machine.
  enum GlobalISelAbortMode
    Enable
    Disable
    DisableWithDiag
  end
end

require "./enums/*"
