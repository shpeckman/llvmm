<!-- AGENTS.md -->
# AGENTS.md

Orientation for AI agents working on llvmm, a Crystal shard providing LLVM bindings
with a focus on JIT (ORCv2) compilation.

## Repository layout

- `src/llvmm.cr` — entry point; `LLVMM` module, target initialization, helpers
- `src/llvmm/` — high-level wrappers: `context.cr`, `module.cr`, `builder.cr`,
  `type.cr`, `value.cr`, `function.cr`, collection types, `target*.cr`, `di_builder.cr`
- `src/llvmm/jit.cr` — `LLVMM::JIT`, the high-level JIT facade
- `src/llvmm/orc/` — raw ORCv2 bindings (`LLJIT`, `ExecutionSession`, `JITDyLib`, …)
- `src/llvmm/lib_llvm.cr` + `src/llvmm/lib_llvm/` — `lib LibLLVMM` FFI declarations,
  `llvm-config` resolution, version gates (`IS_LT_190` … `IS_LT_230`)
- `src/llvmm/ext/` — `find-llvm-config.sh` and `llvm-versions.txt` (supported versions)
- `spec/` — spec suite; `jit_api_spec.cr` and `toy_compiler_spec.cr` exercise the JIT
- `scripts/api_diff.cr` — diffs bindings against the llvm-c headers of an llvmorg tag
- `.github/workflows/` — CI spec matrix (LLVM 18–23) and the weekly API diff

## Commands

- `crystal spec` or `make spec` — run the spec suite (needs a discoverable `llvm-config`)
- `make spec-N` — run against `llvm-config-N`
- `make matrix` / `make matrix-strict` — run across every installed supported LLVM
- `make api-diff` — diff bindings against the newest llvmorg tag
- `make docs` — generate API documentation into `docs/` (`crystal docs`)
- `LLVM_CONFIG=llvm-config-21 crystal spec` — override discovery manually

## Code standards

- Compiler-friendly, performance-focused, idiomatic Crystal; data-driven design
- No comments in code, except:
  - every file starts with a comment containing its own path (e.g.
    `# src/llvmm/jit.cr`, `<!-- README.md -->`)
  - doc comments documenting the public API (consumed by `crystal docs`). Keep
    them factual and concise; document behavior, contract, and ownership/memory
    semantics where relevant. `lib LibLLVMM` FFI declarations only get a brief
    pointer to the upstream LLVM C API documentation.
- Never use `out` as an identifier (reserved keyword)
- Never touch the `version` field in `shard.yml`
- Prevent shotgun surgery: keep related changes in one place
- The usage-facing API must be ergonomic
- Bindings for newer LLVM APIs go behind the `IS_LT_*` version gates in
  `lib_llvm.cr`, never behind runtime checks
- Keep `README.md` and this file in sync with code changes

## Git workflow

All git phases run through `scripts/gitflow.py` (start / commit / feature /
checkpoint / finish / status / tree). `main` stays clean — one squash-merged commit
per session; full history lives on `dev` and `feature/<name>` branches, which are
never deleted and always pushed. Never force-push, never delete branches, never
`reset --hard`; undo with `git revert` or a restore branch.
