#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Run after `./mach configure`: fail in minutes, not hours, when the
# Rust compiler is built on a newer LLVM than the clang used for the
# build. That combination breaks cross-language PGO (startup crash in
# the instrumented browser) and cross-language LTO (link failure).
#
#   usage: scripts/check-toolchain.sh
# ---------------------------------------------------------------------
set -euo pipefail

CLANG="${MOZBUILD_STATE_PATH:-$HOME/.mozbuild}/clang/bin/clang"
[ -x "${CLANG}" ] || { echo "No bootstrapped clang at ${CLANG} (did ./mach configure run?)"; exit 1; }

clang_ver="$("${CLANG}" --version | sed -nE '1s/.*version ([0-9]+(\.[0-9]+)*).*/\1/p')"
rust_ver="$(rustc -vV | sed -n 's/^release: //p')"
rust_llvm="$(rustc -vV | sed -n 's/^LLVM version: //p')"
[ -n "${clang_ver}" ] && [ -n "${rust_llvm}" ] || { echo "Could not read the clang / Rust LLVM versions"; exit 1; }

echo "clang ${clang_ver}; Rust ${rust_ver} (LLVM ${rust_llvm})"
if [ "${rust_llvm%%.*}" -gt "${clang_ver%%.*}" ]; then
  echo "::error::Rust ${rust_ver} is built on LLVM ${rust_llvm}, newer than clang ${clang_ver}. Cross-language PGO/LTO would fail; see scripts/setup-rust.sh."
  exit 1
fi
echo "Toolchains match."
