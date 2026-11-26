# Homebrew tap for SeaHorn and sea-mlir

Homebrew formulae for [SeaHorn](https://github.com/seahorn/seahorn) and
[sea-mlir](https://github.com/seahorn/sea-mlir), with prebuilt bottles.

| formula | what |
|---|---|
| `sea-mlir` | the sea-mlir tools (`sea-vc`, `sea-opt` and the rest), with the pinned z3, Bitwuzla and Yices |
| `seahorn` | SeaHorn (dev18 branch, without Clam), with `sea-mlir` as its VC backend; `sea` compiles C with the `clang` of `llvm@18` |
| `sea-mlir-llvm` | LLVM and MLIR at the revision sea-mlir is pinned to; keg-only, needed only to build `sea-mlir` from source |

## Install

```bash
brew tap seahorn/seahorn
brew trust seahorn/seahorn          # Homebrew 7.0 loads formulae of other taps only once trusted
brew install seahorn/seahorn/seahorn    # SeaHorn, installs sea-mlir too
brew install seahorn/seahorn/sea-mlir   # or only the sea-mlir tools
```

Installing `sea-mlir` or `seahorn` from bottles does not download
`sea-mlir-llvm`.

## Platforms

Bottles exist for Linux x86_64 only. They need glibc 2.38 and the
libstdc++ of GCC 13 or newer (Ubuntu 24.04 or newer). On other systems
`brew install` builds from source, which needs LLVM and MLIR to be built
first (`sea-mlir-llvm`, about an hour on 8 cores).

macOS (arm64) bottles are planned and not available yet.

`sea` compiles C with the system's C headers; its default `-m32` needs the
32-bit headers (`libc6-dev-i386` on Ubuntu), `-m64` does not.

## Documentation

- sea-mlir: https://seahorn.github.io/sea-mlir/. The installed docs are in
  `$(brew --prefix)/share/doc/sea-mlir/docs`; `sea-vc --agent` prints the
  entry page for coding agents.
- SeaHorn: https://github.com/seahorn/seahorn

The formulae are maintained in the sea-mlir repository
(`packaging/homebrew`), where the bottles are built and tested; please
report problems at https://github.com/seahorn/sea-mlir/issues.

## License

The formulae are under the Apache License v2.0 with LLVM Exceptions
([LICENSE](LICENSE)). The installed software carries its own licenses;
each keg ships its license texts under `share/doc`.
