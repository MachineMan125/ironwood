#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Install the Rust version Mozilla builds this Firefox version with.
#
#   usage: scripts/setup-rust.sh <firefox-src-dir>
#
# `--enable-bootstrap` downloads clang, the sysroot and the other tools,
# but not Rust (Mozilla only bootstraps Rust in its own CI); configure
# then takes whatever rustup has as default. On a hosted runner that is
# the newest stable Rust, built on a newer LLVM than Mozilla's clang.
# Cross-language PGO and LTO need Rust's LLVM to be no newer than
# clang's: otherwise the instrumented browser crashes at startup in
# __llvm_profile_instrument_target, and lld cannot read Rust's bitcode.
#
# The version is read from the source tree (the "linux64-rust" toolchain
# in taskcluster/kinds/toolchain/rust.yml). Set RUST_VERSION to override.
# ---------------------------------------------------------------------
set -euo pipefail

SRC="$(cd "${1:?firefox source dir}" && pwd)"
YML="${SRC}/taskcluster/kinds/toolchain/rust.yml"

if [ -n "${RUST_VERSION:-}" ]; then
  VER="${RUST_VERSION}"
  echo ">> Using RUST_VERSION=${VER}"
else
  [ -f "${YML}" ] || { echo "Cannot find ${YML}; set RUST_VERSION (e.g. 1.94.1)"; exit 1; }
  VER="$(python3 - "${YML}" <<'PY'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))
def aliases(a):
    if isinstance(a, dict):
        a = (a.get("by-project") or {}).get("default")
    if a is None:
        return []
    return [a] if isinstance(a, str) else list(a)
found = []
for job in jobs.values():
    run = job.get("run") if isinstance(job, dict) else None
    if not isinstance(run, dict):
        continue
    if "linux64-rust" in aliases(run.get("toolchain-alias")):
        args = run.get("arguments") or []
        if "--channel" in args:
            found.append(args[args.index("--channel") + 1])
if len(found) != 1:
    sys.exit(f"expected exactly one linux64-rust toolchain in rust.yml, found {found}")
print(found[0])
PY
)" || { echo "Could not read Mozilla's Rust version from rust.yml; set RUST_VERSION (e.g. 1.94.1)"; exit 1; }
  echo ">> Mozilla builds this Firefox with Rust ${VER}"
fi

[[ "${VER}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "Unexpected Rust version '${VER}'"; exit 1; }

command -v rustup >/dev/null || { echo "rustup not found; install it from https://rustup.rs"; exit 1; }
rustup toolchain install "${VER}" --profile minimal --no-self-update
rustup default "${VER}"
rustc -vV
