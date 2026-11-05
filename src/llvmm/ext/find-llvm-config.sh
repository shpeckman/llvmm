#!/bin/sh
# src/llvmm/ext/find-llvm-config.sh

if ! LLVM_CONFIG=$(command -v "$LLVM_CONFIG"); then
  versions=$(cat "$(dirname "$0")/llvm-versions.txt")
  llvm_config_version=$(llvm-config --version 2>/dev/null)

  for version in $versions; do
    if [ "${llvm_config_version#"$version"}" != "$llvm_config_version" ]; then
      LLVM_CONFIG=$(command -v llvm-config)
      break
    fi
  done

  if [ ! "$LLVM_CONFIG" ]; then
    for version in $versions; do
      LLVM_CONFIG=$(
        command -v llvm-config-"${version%.*}" ||
          command -v llvm-config-"$version" ||
          command -v "llvm-config${version%.*}${version#*.}" ||
          command -v llvm-config"${version%.*}" ||
          command -v llvm-config"$version" ||
          command -v llvm"${version%.*}"-config
      )
      [ "$LLVM_CONFIG" ] && break
    done
  fi
fi

if [ "$LLVM_CONFIG" ]; then
  case "$(uname -s)" in
    MINGW32_NT* | MINGW64_NT*)
      printf "%s" "$(cygpath -w "$LLVM_CONFIG")"
      ;;
    *)
      printf "%s" "$LLVM_CONFIG"
      ;;
  esac
else
  printf "Error: Could not find location of llvm-config. Please specify path in environment variable LLVM_CONFIG.\n" >&2
  printf "Supported LLVM versions: %s\n" "$(sed 's/\.0//g' "$(dirname "$0")/llvm-versions.txt")" >&2
  exit 1
fi
