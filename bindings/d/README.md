# D Language Bindings for c-kzg-4844

[![D](https://github.com/ethereum/c-kzg-4844/actions/workflows/d-tests.yml/badge.svg)](https://github.com/ethereum/c-kzg-4844/actions/workflows/d-tests.yml)

D language bindings for the c-kzg-4844 library, providing polynomial commitments for EIP-4844 (Proto-Danksharding) and EIP-7594.

## Requirements

- D compiler (DMD or LDC)
- DUB package manager
- C compiler (gcc or clang)
- Make

## Building

From the project root:

```bash
dub build
```

The C library is automatically built via `preBuildCommands`.

## Testing

```bash
dub test
```

## Installation

### As a DUB dependency

Add to your `dub.sdl`:

```sdl
dependency "ckzg" path="path/to/c-kzg-4844"
```

Or `dub.json`:

```json
{
    "dependencies": {
        "ckzg": { "path": "path/to/c-kzg-4844" }
    }
}
```

## Usage

```d
import ckzg;

void main()
{
    // Load trusted setup
    auto setup = TrustedSetup.fromFile("path/to/trusted_setup.txt");

    // Create a blob
    Blob blob;
    blob.bytes[] = 0; // or fill with actual data

    // Compute commitment
    auto commitment = setup.blobToKzgCommitment(blob);

    // Compute proof
    auto proof = setup.computeBlobKzgProof(blob, commitment);

    // Verify proof
    bool valid = setup.verifyBlobKzgProof(blob, commitment, proof);
    assert(valid);

    // EIP-7594: Compute cells and proofs
    auto result = setup.computeCellsAndKzgProofs(blob);
    // result.cells and result.proofs are available
}
```

## API Reference

### Types

| Type | Description |
|------|-------------|
| `Bytes32` | 32-byte array (field elements) |
| `Bytes48` | 48-byte array (commitments/proofs) |
| `Blob` | Blob data (131,072 bytes) |
| `Cell` | Cell data (2,048 bytes) |
| `KZGCommitment` | Alias for `Bytes48` |
| `KZGProof` | Alias for `Bytes48` |
| `C_KZG_RET` | Return code enum (`C_KZG_OK`, `C_KZG_BADARGS`, `C_KZG_ERROR`, `C_KZG_MALLOC`) |
| `KzgException` | Exception thrown on errors |

### TrustedSetup

The main context for KZG operations.

#### Construction

- `TrustedSetup.fromFile(path, precompute=0)` — Load from file
- `TrustedSetup.fromBytes(g1Monomial, g1Lagrange, g2Monomial, precompute=0)` — Load from bytes

#### EIP-4844 Methods

| Method | Description |
|--------|-------------|
| `blobToKzgCommitment(blob)` | Compute commitment from blob |
| `computeKzgProof(blob, z)` | Compute proof at point z |
| `computeBlobKzgProof(blob, commitment)` | Compute blob proof |
| `verifyKzgProof(commitment, z, y, proof)` | Verify proof |
| `verifyBlobKzgProof(blob, commitment, proof)` | Verify blob proof |
| `verifyBlobKzgProofBatch(blobs, commitments, proofs)` | Batch verify |

#### EIP-7594 Methods

| Method | Description |
|--------|-------------|
| `computeCellsAndKzgProofs(blob)` | Extract cells and proofs |
| `recoverCellsAndKzgProofs(indices, cells)` | Recover from samples |
| `verifyCellKzgProofBatch(commitments, indices, cells, proofs)` | Batch verify cells |

## Constants

| Constant | Value |
|----------|-------|
| `BYTES_PER_BLOB` | 131,072 |
| `BYTES_PER_COMMITMENT` | 48 |
| `BYTES_PER_PROOF` | 48 |
| `BYTES_PER_FIELD_ELEMENT` | 32 |
| `BYTES_PER_CELL` | 2,048 |
| `FIELD_ELEMENTS_PER_BLOB` | 4,096 |
| `FIELD_ELEMENTS_PER_CELL` | 64 |
| `CELLS_PER_BLOB` | 64 |
| `CELLS_PER_EXT_BLOB` | 128 |

## Running the Example

```bash
cd bindings/d/example
dub run
```

## Regenerating the C Bindings

`source/ckzg/c.d` is a low-level C binding generated from `ckzg_public.h` using
[dstep](https://github.com/jacob-carlborg/dstep) and is committed to the repository.
Regeneration is only needed when the public C API changes.

### File structure

```
bindings/d/
├── ckzg_public.h          # Facade header used as dstep input
└── source/ckzg/
    ├── c.d                # dstep-generated low-level C bindings
    ├── package.d          # Hand-written high-level D wrapper
    └── test.d             # Tests
```

### Why a facade header?

The actual `src/ckzg.h` pulls in blst internals (`fr_t`, `g1_t`, etc.) through its include
chain, which would cause dstep to translate blst's internal types as well. `ckzg_public.h`
exposes only the public API and represents `KZGSettings` as an opaque type whose size matches
the actual struct (10 pointer-sized fields = 80 bytes on x86_64).

### Prerequisites

dstep requires libclang. On Ubuntu/Debian:

```bash
sudo apt install libclang-dev
```

dstep 1.0.4 does not auto-detect LLVM 18, so the path must be configured manually before
building:

```bash
# Fetch dstep via DUB (this will attempt a build and fail — that is expected)
dub fetch dstep

# Configure libclang path inside the dstep package directory
cd ~/.dub/packages/dstep/1.0.4/dstep
./configure --llvm-path=/usr/lib/llvm-18   # adjust path as needed

# Build dstep
dub build
```

The binary will be at `~/.dub/packages/dstep/1.0.4/dstep/bin/dstep`.

### Generation command

Run from the project root:

```bash
DSTEP=~/.dub/packages/dstep/1.0.4/dstep/bin/dstep

$DSTEP bindings/d/ckzg_public.h \
  --output bindings/d/source/ckzg/c.d \
  --global-attribute="@nogc" \
  --global-attribute="nothrow" \
  --package="ckzg"
```

### Post-generation fix

dstep derives the module name from the input filename. Change the generated module declaration
manually:

```diff
- module ckzg.ckzg_public;
+ module ckzg.c;
```

No other manual edits are needed.

### Verifying the output

```bash
dub build
dub test
```

### When to update `ckzg_public.h`

Update the facade header when:

- A public API function signature changes
- Constants are added or modified
- Type definitions change
- The number of fields in `KZGSettings` changes (update the opaque array size accordingly)

```c
/* Count the fields in settings.h and adjust (each field is pointer-sized) */
typedef struct {
    uint64_t _opaque[10];  /* number of fields x 8 bytes */
} KZGSettings;
```

## License

Apache-2.0
