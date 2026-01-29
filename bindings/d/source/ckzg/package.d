/**
 * D language bindings for c-kzg-4844.
 *
 * Minimal implementation of the polynomial commitments API for EIP-4844 and EIP-7594.
 *
 * Copyright: Copyright 2024 Benjamin Edgington
 * License: Apache-2.0
 */
module ckzg;

public import ckzg.c;

import core.stdc.stdio : FILE, fopen, fclose;
import core.stdc.stdlib : malloc, free;

///////////////////////////////////////////////////////////////////////////////
// Helpers (usable via UFCS)
///////////////////////////////////////////////////////////////////////////////

/// Convert Bytes32 to lowercase hex string.
string toHex(ref const Bytes32 b) pure @safe
{
    static immutable hexDigits = "0123456789abcdef";
    char[64] result;
    foreach (i, x; b.bytes)
    {
        result[i * 2] = hexDigits[x >> 4];
        result[i * 2 + 1] = hexDigits[x & 0x0F];
    }
    return result[].idup;
}

/// Convert Bytes48 to lowercase hex string.
string toHex(ref const Bytes48 b) pure @safe
{
    static immutable hexDigits = "0123456789abcdef";
    char[96] result;
    foreach (i, x; b.bytes)
    {
        result[i * 2] = hexDigits[x >> 4];
        result[i * 2 + 1] = hexDigits[x & 0x0F];
    }
    return result[].idup;
}

///////////////////////////////////////////////////////////////////////////////
// Exception
///////////////////////////////////////////////////////////////////////////////

/// Exception thrown when a KZG operation fails.
class KzgException : Exception
{
    /// The error code returned by the C library.
    C_KZG_RET errorCode;

    /// Construct a KzgException from an error code.
    this(C_KZG_RET code, string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        errorCode = code;
        string msg = () {
            final switch (code)
            {
            case C_KZG_OK:
                return "Success";
            case C_KZG_BADARGS:
                return "Invalid arguments";
            case C_KZG_ERROR:
                return "Internal error";
            case C_KZG_MALLOC:
                return "Memory allocation failed";
            }
        }();
        super(msg, file, line);
    }
}

///////////////////////////////////////////////////////////////////////////////
// High-level D Wrapper
///////////////////////////////////////////////////////////////////////////////

/**
 * Trusted setup context that manages the lifetime of KZGSettings.
 *
 * Use `TrustedSetup.fromFile` or `TrustedSetup.fromBytes` to create.
 */
struct TrustedSetup
{
    private KZGSettings* settings;

    @disable this(this); // No copying

    private this(KZGSettings* s) @nogc nothrow
    {
        settings = s;
    }

    ~this() @trusted @nogc nothrow
    {
        if (settings !is null)
        {
            free_trusted_setup(settings);
            () @trusted { free(settings); }();
            settings = null;
        }
    }

    /**
     * Load trusted setup from a file.
     *
     * Params:
     *   path = Path to the trusted_setup.txt file
     *   precompute = Precomputation level (0 = minimal, higher = faster but more memory)
     *
     * Returns: TrustedSetup instance
     * Throws: KzgException on failure
     */
    static TrustedSetup fromFile(string path, ulong precompute = 0) @trusted
    {
        import std.string : toStringz;

        auto s = cast(KZGSettings*) malloc(KZGSettings.sizeof);
        if (s is null)
            throw new KzgException(C_KZG_MALLOC);

        FILE* file = fopen(path.toStringz, "r");
        if (file is null)
        {
            free(s);
            throw new KzgException(C_KZG_BADARGS);
        }

        scope (exit) fclose(file);

        auto ret = load_trusted_setup_file(s, file, precompute);
        if (ret != C_KZG_OK)
        {
            free(s);
            throw new KzgException(ret);
        }

        return TrustedSetup(s);
    }

    /**
     * Load trusted setup from byte arrays.
     *
     * Params:
     *   g1Monomial = G1 points in monomial form
     *   g1Lagrange = G1 points in Lagrange form
     *   g2Monomial = G2 points in monomial form
     *   precompute = Precomputation level
     *
     * Returns: TrustedSetup instance
     * Throws: KzgException on failure
     */
    static TrustedSetup fromBytes(
        const(ubyte)[] g1Monomial,
        const(ubyte)[] g1Lagrange,
        const(ubyte)[] g2Monomial,
        ulong precompute = 0,
    ) @trusted
    {
        auto s = cast(KZGSettings*) malloc(KZGSettings.sizeof);
        if (s is null)
            throw new KzgException(C_KZG_MALLOC);

        auto ret = load_trusted_setup(
            s,
            g1Monomial.ptr,
            g1Monomial.length,
            g1Lagrange.ptr,
            g1Lagrange.length,
            g2Monomial.ptr,
            g2Monomial.length,
            precompute,
        );
        if (ret != C_KZG_OK)
        {
            free(s);
            throw new KzgException(ret);
        }

        return TrustedSetup(s);
    }

    /// Check if the setup is valid and initialized.
    bool isValid() const @nogc nothrow
    {
        return settings !is null;
    }

    // EIP-4844 Functions

    /// Compute a KZG commitment from a blob.
    KZGCommitment blobToKzgCommitment(ref const Blob blob) const @trusted
    {
        KZGCommitment commitment;
        auto ret = blob_to_kzg_commitment(&commitment, &blob, settings);
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return commitment;
    }

    /// Compute a KZG proof for a blob at a given point.
    auto computeKzgProof(ref const Blob blob, ref const Bytes32 z) const @trusted
    {
        struct Result
        {
            KZGProof proof;
            Bytes32 y;
        }

        Result result;
        auto ret = compute_kzg_proof(&result.proof, &result.y, &blob, &z, settings);
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return result;
    }

    /// Compute a KZG proof for a blob with a given commitment.
    KZGProof computeBlobKzgProof(ref const Blob blob, ref const Bytes48 commitment) const @trusted
    {
        KZGProof proof;
        auto ret = compute_blob_kzg_proof(&proof, &blob, &commitment, settings);
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return proof;
    }

    /// Verify a KZG proof.
    bool verifyKzgProof(
        ref const Bytes48 commitment,
        ref const Bytes32 z,
        ref const Bytes32 y,
        ref const Bytes48 proof,
    ) const @trusted
    {
        bool ok;
        auto ret = verify_kzg_proof(&ok, &commitment, &z, &y, &proof, settings);
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return ok;
    }

    /// Verify a blob KZG proof.
    bool verifyBlobKzgProof(
        ref const Blob blob,
        ref const Bytes48 commitment,
        ref const Bytes48 proof,
    ) const @trusted
    {
        bool ok;
        auto ret = verify_blob_kzg_proof(&ok, &blob, &commitment, &proof, settings);
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return ok;
    }

    /// Verify multiple blob KZG proofs in a batch.
    bool verifyBlobKzgProofBatch(
        const Blob[] blobs,
        const Bytes48[] commitments,
        const Bytes48[] proofs,
    ) const @trusted
    in (blobs.length == commitments.length)
    in (blobs.length == proofs.length)
    {
        if (blobs.length == 0)
            return true;

        bool ok;
        auto ret = verify_blob_kzg_proof_batch(
            &ok,
            blobs.ptr,
            commitments.ptr,
            proofs.ptr,
            blobs.length,
            settings,
        );
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return ok;
    }

    // EIP-7594 Functions

    /// Compute cells and KZG proofs for a blob.
    auto computeCellsAndKzgProofs(ref const Blob blob) const @trusted
    {
        struct Result
        {
            Cell[CELLS_PER_EXT_BLOB] cells;
            KZGProof[CELLS_PER_EXT_BLOB] proofs;
        }

        Result result;
        auto ret = compute_cells_and_kzg_proofs(
            result.cells.ptr, result.proofs.ptr, &blob, settings,
        );
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return result;
    }

    /// Recover cells and KZG proofs from a subset of cells.
    auto recoverCellsAndKzgProofs(
        const ulong[] cellIndices,
        const Cell[] cells,
    ) const @trusted
    in (cellIndices.length == cells.length)
    {
        struct Result
        {
            Cell[CELLS_PER_EXT_BLOB] cells;
            KZGProof[CELLS_PER_EXT_BLOB] proofs;
        }

        Result result;
        auto ret = recover_cells_and_kzg_proofs(
            result.cells.ptr,
            result.proofs.ptr,
            cellIndices.ptr,
            cells.ptr,
            cells.length,
            settings,
        );
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return result;
    }

    /// Verify multiple cell KZG proofs in a batch.
    bool verifyCellKzgProofBatch(
        const Bytes48[] commitments,
        const ulong[] cellIndices,
        const Cell[] cells,
        const Bytes48[] proofs,
    ) const @trusted
    in (cellIndices.length == cells.length)
    in (cells.length == proofs.length)
    {
        if (cells.length == 0)
            return true;

        bool ok;
        auto ret = verify_cell_kzg_proof_batch(
            &ok,
            commitments.ptr,
            cellIndices.ptr,
            cells.ptr,
            proofs.ptr,
            cells.length,
            settings,
        );
        if (ret != C_KZG_OK)
            throw new KzgException(ret);
        return ok;
    }
}
