# src/llvmm.cr
require "./llvmm/**"
require "c/string"

# Top-level namespace of llvmm, providing global LLVM services: target
# initialization, host/target queries, and the new pass manager
# (`run_passes`). The IR-building and JIT APIs live in the types nested
# under this module (`Context`, `Module`, `Builder`, `JIT`, `Orc`, ...).
module LLVMM
  # Returns the version of the linked LLVM library as `"major.minor.patch"`.
  def self.version
    LibLLVMM.get_version(out major, out minor, out patch)
    "#{major}.#{minor}.#{patch}"
  end

  {% for target in LibLLVMM::ALL_TARGETS %}
    {% name = target.downcase.id %}
    @@initialized_{{name}} = Atomic(Bool).new(false)

    # Initializes this target: target info, target, MC layer, asm printer and
    # parser, the disassembler (where available), and links in the MCJIT.
    # Idempotent and thread-safe. Raises if the linked LLVM was built without
    # this target.
    def self.init_{{name}} : Nil
      return if @@initialized_{{name}}.swap(true)

      \{% if LibLLVMM::BUILT_TARGETS.includes?({{name.symbolize}}) %}
        LibLLVMM.initialize_{{name}}_target_info
        LibLLVMM.initialize_{{name}}_target
        LibLLVMM.initialize_{{name}}_target_mc
        LibLLVMM.initialize_{{name}}_asm_printer
        LibLLVMM.initialize_{{name}}_asm_parser
        \{% if LibLLVMM::DISASSEMBLER_TARGETS.includes?({{target}}) %}
          LibLLVMM.initialize_{{name}}_disassembler
        \{% end %}
        LibLLVMM.link_in_mc_jit
      \{% else %}
        raise "ERROR: LLVM was built without {{target.id}} target"
      \{% end %}
    end
  {% end %}

  # Initializes the target matching the host platform (delegates to the
  # matching `init_*` method). Fails to compile on unsupported platforms.
  def self.init_native_target : Nil
    {% if flag?(:i386) || flag?(:x86_64) %}
      init_x86
    {% elsif flag?(:aarch64) %}
      init_aarch64
    {% elsif flag?(:arm) %}
      init_arm
    {% elsif flag?(:wasm32) %}
      init_webassembly
    {% elsif flag?(:avr) %}
      init_avr
    {% else %}
      {% raise "Unsupported platform" %}
    {% end %}
  end

  # Initializes every target the linked LLVM was built with.
  def self.init_all_targets : Nil
    {% for target in LibLLVMM::ALL_TARGETS %}
      {% name = target.downcase.id %}
      \{% if LibLLVMM::BUILT_TARGETS.includes?({{name.symbolize}}) %}
        init_{{name}}
      \{% end %}
    {% end %}
  end

  # Whether the linked LLVM was built with multithreading support.
  def self.multithreaded? : Bool
    LibLLVMM.is_multithreaded != 0
  end

  # The default target triple of the host, as reported by LLVM. Known
  # version-suffixed triples (Android, Solaris) are truncated to their
  # canonical prefix.
  def self.default_target_triple : String
    chars = LibLLVMM.get_default_target_triple
    case triple = string_and_dispose(chars)
    when .starts_with?("aarch64-unknown-linux-android")
      "aarch64-unknown-linux-android"
    when .starts_with?("x86_64-pc-solaris")
      "x86_64-pc-solaris"
    else
      triple
    end
  end

  # The host CPU name as detected by LLVM (e.g. `"znver3"`), suitable for
  # `Target#create_target_machine`.
  def self.host_cpu_name : String
    String.new LibLLVMM.get_host_cpu_name
  end

  # The host CPU features as a comma-separated string, as detected by LLVM.
  def self.host_cpu_features : String
    LLVMM.string_and_dispose LibLLVMM.get_host_cpu_features
  end

  # Returns the LLVM-normalized (canonical) form of a target triple.
  def self.normalize_triple(triple : String) : String
    normalized = LibLLVMM.normalize_target_triple(triple)
    normalized = LLVMM.string_and_dispose(normalized)

    normalized
  end

  # Writes an LLVM-allocated, NUL-terminated message to *io* and disposes it
  # with `LLVMDisposeMessage`.
  def self.to_io(chars, io) : Nil
    io.write_string Slice.new(chars, LibC.strlen(chars))
    LibLLVMM.dispose_message(chars)
  end

  # Copies an LLVM-allocated message into a `String` and disposes the
  # original with `LLVMDisposeMessage`.
  def self.string_and_dispose(chars) : String
    string = String.new(chars)
    LibLLVMM.dispose_message(chars)
    string
  end

  # Passes *options* to LLVM's command-line option parser
  # (`cl::ParseCommandLineOptions`), e.g. to tune LLVM internals; *overview*
  # is the description shown in LLVM's `--help` output.
  def self.parse_command_line_options(options : Enumerable(String), overview : String = "") : Nil
    c_strs = options.to_a(&.to_unsafe)
    LibLLVMM.parse_command_line_options(c_strs.size, c_strs, overview)
  end

  protected def self.assert(error : LibLLVMM::ErrorRef)
    if error
      chars = LibLLVMM.get_error_message(error)
      raise String.new(chars).tap { LibLLVMM.dispose_error_message(chars) }
    end
  end

  # Runs a new-pass-manager pipeline described by *passes* (e.g.
  # `"default<O2>"`) on *mod*. Returns the underlying
  # `LibLLVMM::ErrorRef`, which is null on success.
  def self.run_passes(mod : Module, passes : String, target_machine : TargetMachine, options : PassBuilderOptions)
    LibLLVMM.run_passes(mod, passes, target_machine, options)
  end

  {% unless LibLLVMM::IS_LT_200 %}
    # Runs a new-pass-manager pipeline described by *passes* on a single
    # function. Requires LLVM 20+ (gated on `IS_LT_200`).
    def self.run_passes_on_function(func : Function, passes : String, target_machine : TargetMachine, options : PassBuilderOptions)
      LibLLVMM.run_passes_on_function(func, passes, target_machine, options)
    end
  {% end %}

  # Value to use for the `"Debug Info Version"` module flag when attaching
  # debug info to a module (see `Module#add_flag` and `DIBuilder`).
  DEBUG_METADATA_VERSION = 3

  # The debug metadata version used by the linked LLVM.
  def self.debug_metadata_version : UInt32
    LibLLVMM.debug_metadata_version
  end
end
