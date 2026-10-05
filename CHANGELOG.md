<!-- CHANGELOG.md -->
# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- API documentation: doc comments across the public API, generated with
  `crystal docs` (`make docs`)
- Regression specs for disposal and ownership-transfer behavior

### Fixed

- `JITCompiler#dispose` and `MemoryBuffer#dispose` never released the
  underlying LLVM object due to a finalize-guard ordering bug
- `Context#parse_ir` and `Module.parse` could double-dispose the
  `MemoryBuffer` on GC finalization; buffer ownership is now transferred to
  LLVM, and reusing a consumed buffer raises
- `LLVMM.run_passes` / `LLVMM.run_passes_on_function` returned the raw error
  ref instead of raising; they now raise with LLVM's error message on failure

## [0.2.0]

### Added

- `LLVMM::JIT` high-level JIT facade: module management, typed `jit.function(...)`
  lookups returning callable Crystal procs, signature verification, and symbol
  resolution (`link_process_symbols`, `link_symbols_from_path`, `define`)
- Full ORCv2 bindings under `LLVMM::Orc`: `LLJITBuilder`, `LLJIT`, `ExecutionSession`,
  `JITDyLib`, `ResourceTracker`, `ThreadSafeContext`, `ThreadSafeModule`,
  `IRTransformLayer`, `ObjectTransformLayer`, `SymbolStringPool`,
  `DefinitionGenerator`, `ObjectLayer`
- `LLVMM::DIBuilder` for debug metadata
- `LLVMM::Disassembler`
- New pass manager entry points: `LLVMM.run_passes`,
  `LLVMM.run_passes_on_function` (LLVM >= 20), `PassBuilderOptions`
- Version-gated bindings for LLVM 18–23 (`IS_LT_190` … `IS_LT_230`)
- `make spec-N` / `make matrix` / `make matrix-strict` for testing across
  installed LLVM versions
- `scripts/api_diff.cr` and a weekly CI workflow to diff the bindings against
  the newest llvmorg tag
- CI matrix covering LLVM 18–23

## [0.1.0]

### Added

- Initial `LLVMM::Context`, `Module`, `Builder`, `Type`, `Value`, `Function`,
  `BasicBlock`, and collection wrappers
- `Target`, `TargetMachine`, `TargetData` and native/all target initialization
- `llvm-config` discovery via `src/llvmm/ext/find-llvm-config.sh` with the
  `LLVM_CONFIG` override
