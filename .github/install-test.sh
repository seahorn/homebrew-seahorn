#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The sea-mlir Authors
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

# Install test of this tap on a machine with Homebrew 7.0 or newer, by
# .github/workflows/install-test.yml and, in a clean ghcr.io/homebrew/brew
# container, by hand. Two steps:
#
#   install-test.sh tap TAPDIR
#       taps the working tree TAPDIR as seahorn/seahorn (a symlink, so a
#       pull request tests its own formulae), trusts it, prints
#       `sea-mlir-version: <version>` (the sea-mlir checkout of `check`
#       is the tag v<version>)
#   install-test.sh check SEA_MLIR_DIR
#       installs seahorn (and with it sea-mlir), fails unless every
#       installed formula was poured from a bottle, `brew linkage --test
#       --strict`, `brew test`; sea-mlir's tarball smoke
#       (SEA_MLIR_DIR/docker/smoke/check.sh) on the sea-mlir keg; the
#       SeaHorn export flow on docker/smoke/{sat,unsat}.c, as
#       docker/homebrew-smoke.sh of sea-mlir; then sea-mlir-llvm alone.
#
# check.sh's `libs` check is expected to fail: it requires every linked
# library inside the prefix or in the system (the rule of the release
# tarball), and the keg links gmp and mpfr from the Homebrew prefix. `brew
# linkage --test --strict` and the `not found` scan below replace it.
set -euo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1

poured() {
  # every installed keg, homebrew-core's included
  # shellcheck disable=SC2016 # Ruby code, not shell
  brew ruby -e '
    built = Formula.installed.reject { |f| f.any_installed_keg&.tab&.poured_from_bottle }
    abort "built from source, not poured: #{built.map(&:full_name).join(" ")}" unless built.empty?
    puts "poured from bottles: #{Formula.installed.map(&:full_name).sort.join(" ")}"
  '
}

case "${1:-}" in
tap)
  [[ $# -eq 2 ]] || { echo 'usage: install-test.sh tap TAPDIR' >&2; exit 2; }
  tapdir=$(CDPATH='' cd -- "$2" && pwd -P)
  [[ -f "$tapdir/Formula/sea-mlir.rb" ]] || { echo "$tapdir: no Formula/sea-mlir.rb" >&2; exit 2; }
  brew --version
  # brew trust is new in Homebrew 7.0
  major=$(brew --version | sed -n '1s/^Homebrew \([0-9]*\)\..*/\1/p')
  [[ -n "$major" && "$major" -ge 7 ]] || { echo 'Homebrew 7.0 or newer is required' >&2; exit 1; }
  taps=$(brew --repository)/Library/Taps/seahorn
  [[ ! -e "$taps/homebrew-seahorn" ]] || { echo 'seahorn/seahorn is already tapped' >&2; exit 1; }
  mkdir -p "$taps"
  ln -s "$tapdir" "$taps/homebrew-seahorn"
  brew tap | grep -qx seahorn/seahorn
  brew trust seahorn/seahorn
  printf 'sea-mlir-version: %s\n' \
    "$(brew ruby -e 'puts Formula["seahorn/seahorn/sea-mlir"].version')"
  ;;
check)
  [[ $# -eq 2 ]] || { echo 'usage: install-test.sh check SEA_MLIR_DIR' >&2; exit 2; }
  smoke=$(CDPATH='' cd -- "$2/docker/smoke" && pwd)
  version=$(brew ruby -e 'puts Formula["seahorn/seahorn/sea-mlir"].version')
  start=$SECONDS
  brew install seahorn/seahorn/seahorn
  echo "time: install $((SECONDS - start)) s"
  poured
  if brew list --versions seahorn/seahorn/sea-mlir-llvm; then
    echo 'sea-mlir-llvm was installed: a bottle install must not need it' >&2
    exit 1
  fi
  brew list --versions
  brew linkage --test --strict seahorn/seahorn/sea-mlir seahorn/seahorn/seahorn
  brew test seahorn/seahorn/sea-mlir seahorn/seahorn/seahorn
  prefix=$(brew --prefix)
  for binary in "$prefix"/bin/sea*; do
    if head -c4 "$binary" | grep -q ELF; then
      if ldd "$binary" | grep 'not found'; then echo "$binary: missing library" >&2; exit 1; fi
    fi
  done
  work=$(mktemp -d)
  cd "$work"
  # the tarball smoke on the keg; the tag must show in --version and DOCS-WEB
  SMOKE_TAG="v$version" SMOKE_XFAIL=libs sh "$smoke/check.sh" "$(brew --prefix seahorn/seahorn/sea-mlir)"
  # --agent from the brew prefix's bin names the docs of the keg
  sea-vc --agent > agent.txt
  sed -n '1,3p' agent.txt
  grep -q "^DOCS: $prefix/.*share/doc/sea-mlir (installed" agent.txt
  root=$(sed -n 's/^DOCS: \([^ ]*\) .*/\1/p' agent.txt)
  test -f "$root/docs/agents/index.md"
  # C -> SeaHorn export -> sea-vc (sea's -m64 needs no 32-bit headers)
  for verdict in sat unsat; do
    sea yama -y sea-mlir-export -m64 --horn-sea-mlir-out="$verdict.mlir" \
      "$smoke/$verdict.c" > "$verdict-export.log" 2>&1 ||
      { cat "$verdict-export.log"; exit 1; }
    grep -q sea.nondet "$verdict.mlir"
    sea-vc "$verdict.mlir" --lower > "$verdict-export-vc.log"
    cat "$verdict-export-vc.log"
    grep -q "^result: $verdict\$" "$verdict-export-vc.log"
    if [[ "$verdict" == sat ]]; then
      grep -q '^replay: assert-failed' "$verdict-export-vc.log"
      grep -q 'mismatches=0' "$verdict-export-vc.log"
    fi
  done
  # the LLVM bottle (a build dependency of sea-mlir only)
  brew install seahorn/seahorn/sea-mlir-llvm
  poured
  brew test seahorn/seahorn/sea-mlir-llvm
  echo 'install-test: pass'
  ;;
*)
  echo 'usage: install-test.sh tap TAPDIR | check SEA_MLIR_DIR' >&2
  exit 2
  ;;
esac
