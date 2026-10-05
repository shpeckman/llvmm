<!-- README.md -->
# llvmm

LLVM bindings for [Crystal](https://crystal-lang.org), focused on JIT compilation.

Crystal's standard library ships an `LLVM` module, but it is only maintained as far as
the Crystal compiler itself needs it. **llvmm** is an independent shard that tracks the
LLVM C API across LLVM 18–23, with first-class support for the ORCv2 JIT stack: build
IR, hand it to an LLJIT instance, and call the compiled code like an ordinary Crystal proc.

## Requirements

- Crystal `>= 1.21.0`
- LLVM 18–23 development files (`llvm-config` must be discoverable)

On Fedora: `sudo dnf install llvm-devel`
On Debian/Ubuntu: `sudo apt install llvm-dev` (or a versioned package such as `llvm-21-dev`)

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  llvmm:
    github: shpeckman/llvmm
```

Then run:

```sh
shards install
```

### LLVM discovery

At compile time llvmm locates `llvm-config` via `src/llvmm/ext/find-llvm-config.sh`,
which probes the versions listed in `src/llvmm/ext/llvm-versions.txt`. To override
discovery, set `LLVM_CONFIG`:

```sh
LLVM_CONFIG=llvm-config-21 crystal build my_app.cr
```

`LLVM_VERSION`, `LLVM_TARGETS`, and `LLVM_LDFLAGS` can also be set explicitly to bypass
`llvm-config` entirely.

## Quick start: JIT in ten lines

```crystal
require "llvmm"

LLVMM::JIT.new do |jit|
  mod = jit.new_module("example")
  add = mod.functions.add("add", [jit.context.int32, jit.context.int32], jit.context.int32)
  add.basic_blocks.append("entry") do |builder|
    builder.ret(builder.add(add.params[0], add.params[1]))
  end
  jit.add_module(mod)

  jit.function("add", Int32, Int32, Int32).call(19, 23) # => 42
end
```

`jit.function(name, Arg1, Arg2, ..., Return)` type-checks the requested signature
against the module at runtime and returns a callable Crystal `Proc`. Argument and
return types map as follows:

| Crystal type                        | LLVM type                |
| ----------------------------------- | ------------------------ |
| `Bool`                              | `i1`                     |
| `Int8`–`Int128`, `UInt8`–`UInt128`  | `i8`–`i128`              |
| `Float32` / `Float64`               | `float` / `double`       |
| `Pointer(T)`                        | opaque pointer (`ptr`)   |
| `StaticArray(T, N)`                 | `[N x T]` (by value)     |
| structs (by value)                  | `{ field0, field1, ... }`|
| `Nil`                               | `void` (return only)     |

### Linking external symbols

JIT'd code can call into the host process or into shared libraries:

```crystal
jit.link_process_symbols          # resolve against the current process
jit.link_symbols_from_path(path)  # resolve against a shared library

fun my_helper(x : Int32) : Int32
  x * 2
end

jit.define("my_helper", Pointer(Void).new(->my_helper(Int32).pointer.address))
```

## Beyond the JIT facade

`LLVMM::JIT` is a convenience layer. The full API surface is available directly:

- `LLVMM::Context`, `LLVMM::Module`, `LLVMM::Builder` — IR construction
- `LLVMM::Target`, `LLVMM::TargetMachine`, `LLVMM::TargetData` — codegen configuration
- `LLVMM.run_passes(mod, passes, target_machine, options)` — the new pass manager
- `LLVMM::Orc::*` — the raw ORCv2 bindings: `LLJITBuilder`, `LLJIT`, `ExecutionSession`,
  `JITDyLib`, `ResourceTracker`, `ThreadSafeContext`, `ThreadSafeModule`, and more
- `LLVMM::DIBuilder` — debug metadata
- `LLVMM.init_native_target` / `LLVMM.init_all_targets` — target initialization

## Development

```sh
make spec           # run the spec suite against the default llvm-config
make spec-21        # run against a specific version (llvm-config-21)
make matrix         # run against every installed supported LLVM version
make matrix-strict  # same, but fail if any supported version is missing
make api-diff       # diff bindings against the llvm-c headers of the newest llvmorg tag
```

CI runs the spec suite against LLVM 18, 19, 20, 21, 22, and 23 on every push and
pull request.

## License

[MIT](LICENSE)
