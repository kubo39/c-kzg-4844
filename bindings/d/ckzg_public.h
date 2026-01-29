/*
 * Facade header for dstep binding generation.
 * Exposes only the public API of c-kzg-4844, treating KZGSettings as opaque.
 *
 * KZGSettings actual layout (settings.h):
 *   10 fields x 8 bytes = 80 bytes on x86_64
 */

#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdbool.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////////////////////////////////////////////////////////

/** The number of bytes in a KZG commitment. */
#define BYTES_PER_COMMITMENT 48

/** The number of bytes in a KZG proof. */
#define BYTES_PER_PROOF 48

/** The number of bytes in a BLS scalar field element. */
#define BYTES_PER_FIELD_ELEMENT 32

/** The number of field elements in a blob. */
#define FIELD_ELEMENTS_PER_BLOB 4096

/** The number of bytes in a blob. */
#define BYTES_PER_BLOB (FIELD_ELEMENTS_PER_BLOB * BYTES_PER_FIELD_ELEMENT)

/** The number of field elements in a cell. */
#define FIELD_ELEMENTS_PER_CELL 64

/** The number of bytes in a single cell. */
#define BYTES_PER_CELL (FIELD_ELEMENTS_PER_CELL * BYTES_PER_FIELD_ELEMENT)

/** The number of cells in a blob. */
#define CELLS_PER_BLOB (FIELD_ELEMENTS_PER_BLOB / FIELD_ELEMENTS_PER_CELL)

/** The number of cells in an extended blob. */
#define CELLS_PER_EXT_BLOB 128

////////////////////////////////////////////////////////////////////////////////////////////////////
// Types
////////////////////////////////////////////////////////////////////////////////////////////////////

/** The common return type for all routines in which something can go wrong. */
typedef enum {
    C_KZG_OK = 0,      /**< Success! */
    C_KZG_BADARGS = 1, /**< The supplied data is invalid in some way. */
    C_KZG_ERROR = 2,   /**< Internal error - this should never occur. */
    C_KZG_MALLOC = 3,  /**< Could not allocate memory. */
} C_KZG_RET;

/** An array of 32 bytes. Represents an untrusted (potentially invalid) field element. */
typedef struct {
    uint8_t bytes[32];
} Bytes32;

/** An array of 48 bytes. Represents an untrusted (potentially invalid) commitment/proof. */
typedef struct {
    uint8_t bytes[48];
} Bytes48;

/** A basic blob data. */
typedef struct {
    uint8_t bytes[BYTES_PER_BLOB];
} Blob;

/** A single cell for a blob. */
typedef struct {
    uint8_t bytes[BYTES_PER_CELL];
} Cell;

/** A trusted (valid) KZG commitment. */
typedef Bytes48 KZGCommitment;

/** A trusted (valid) KZG proof. */
typedef Bytes48 KZGProof;

/**
 * Stores the setup and parameters needed for computing KZG proofs.
 * Treated as opaque: internal fields depend on blst internals.
 * Size: 10 fields x 8 bytes = 80 bytes on x86_64.
 */
typedef struct {
    uint64_t _opaque[10];
} KZGSettings;

////////////////////////////////////////////////////////////////////////////////////////////////////
// Public Functions
////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
extern "C" {
#endif

/* Setup */
C_KZG_RET load_trusted_setup(
    KZGSettings *out,
    const uint8_t *g1_monomial_bytes,
    uint64_t num_g1_monomial_bytes,
    const uint8_t *g1_lagrange_bytes,
    uint64_t num_g1_lagrange_bytes,
    const uint8_t *g2_monomial_bytes,
    uint64_t num_g2_monomial_bytes,
    uint64_t precompute
);

C_KZG_RET load_trusted_setup_file(KZGSettings *out, FILE *in, uint64_t precompute);

void free_trusted_setup(KZGSettings *s);

/* EIP-4844 */
C_KZG_RET blob_to_kzg_commitment(KZGCommitment *out, const Blob *blob, const KZGSettings *s);

C_KZG_RET compute_kzg_proof(
    KZGProof *proof_out,
    Bytes32 *y_out,
    const Blob *blob,
    const Bytes32 *z_bytes,
    const KZGSettings *s
);

C_KZG_RET compute_blob_kzg_proof(
    KZGProof *out, const Blob *blob, const Bytes48 *commitment_bytes, const KZGSettings *s
);

C_KZG_RET verify_kzg_proof(
    bool *ok,
    const Bytes48 *commitment_bytes,
    const Bytes32 *z_bytes,
    const Bytes32 *y_bytes,
    const Bytes48 *proof_bytes,
    const KZGSettings *s
);

C_KZG_RET verify_blob_kzg_proof(
    bool *ok,
    const Blob *blob,
    const Bytes48 *commitment_bytes,
    const Bytes48 *proof_bytes,
    const KZGSettings *s
);

C_KZG_RET verify_blob_kzg_proof_batch(
    bool *ok,
    const Blob *blobs,
    const Bytes48 *commitments_bytes,
    const Bytes48 *proofs_bytes,
    uint64_t n,
    const KZGSettings *s
);

/* EIP-7594 */
C_KZG_RET compute_cells_and_kzg_proofs(
    Cell *cells, KZGProof *proofs, const Blob *blob, const KZGSettings *s
);

C_KZG_RET recover_cells_and_kzg_proofs(
    Cell *recovered_cells,
    KZGProof *recovered_proofs,
    const uint64_t *cell_indices,
    const Cell *cells,
    uint64_t num_cells,
    const KZGSettings *s
);

C_KZG_RET verify_cell_kzg_proof_batch(
    bool *ok,
    const Bytes48 *commitments_bytes,
    const uint64_t *cell_indices,
    const Cell *cells,
    const Bytes48 *proofs_bytes,
    uint64_t num_cells,
    const KZGSettings *s
);

#ifdef __cplusplus
}
#endif
