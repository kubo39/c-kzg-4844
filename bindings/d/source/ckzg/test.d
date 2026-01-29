/**
 * Unit tests for c-kzg-4844 D bindings.
 *
 * Copyright: Copyright 2024 Benjamin Edgington
 * License: Apache-2.0
 */
module ckzg.test;

import ckzg;
import core.exception : AssertError;
import std.process : environment;
import std.path : buildPath, dirName;
import std.file : exists, thisExePath;

/// Get the path to the trusted setup file
private string getTrustedSetupPath()
{
    // Try environment variable first
    auto envPath = environment.get("TRUSTED_SETUP_PATH", "");
    if (envPath.length > 0 && exists(envPath))
        return envPath;

    // Try relative to executable
    string exeDir = dirName(thisExePath());

    // Common paths to try
    string[] paths = [
        buildPath(exeDir, "src", "trusted_setup.txt"),
        buildPath(exeDir, "..", "src", "trusted_setup.txt"),
        "src/trusted_setup.txt",
    ];

    foreach (p; paths)
    {
        if (exists(p))
            return p;
    }

    // Default fallback
    return "src/trusted_setup.txt";
}

// Shared setup for tests
private TrustedSetup loadSetup()
{
    return TrustedSetup.fromFile(getTrustedSetupPath());
}

/// Test Bytes32 operations
unittest
{
    Bytes32 b;
    b.bytes[] = 0;
    assert(b.bytes[0] == 0);

    b.bytes[0] = 0xAB;
    assert(b.bytes[0] == 0xAB);

    auto hex = b.toHex();
    assert(hex.length == 64);
    assert(hex[0 .. 2] == "ab");
}

/// Test Bytes48 operations
unittest
{
    Bytes48 b;
    b.bytes[] = 0;
    assert(b.bytes[0] == 0);

    b.bytes[0] = 0xCD;
    assert(b.bytes[0] == 0xCD);

    auto hex = b.toHex();
    assert(hex.length == 96);
    assert(hex[0 .. 2] == "cd");
}

/// Test Blob operations
unittest
{
    Blob blob;
    blob.bytes[] = 0;
    assert(blob.bytes[0] == 0);
    assert(blob.bytes[].length == BYTES_PER_BLOB);
}

/// Test loading trusted setup
unittest
{
    auto setup = loadSetup();
    assert(setup.isValid());
}

/// Test blob to commitment
unittest
{
    auto setup = loadSetup();

    Blob blob;
    blob.bytes[] = 0;

    auto commitment = setup.blobToKzgCommitment(blob);
    assert(commitment.bytes[0] == 0xc0); // Point at infinity
}

/// Test compute and verify blob proof
unittest
{
    auto setup = loadSetup();

    Blob blob;
    blob.bytes[] = 0;

    auto commitment = setup.blobToKzgCommitment(blob);
    auto proof = setup.computeBlobKzgProof(blob, commitment);

    const valid = setup.verifyBlobKzgProof(blob, commitment, proof);
    assert(valid, "Proof should be valid");
}

/// Test batch verification with single blob
unittest
{
    auto setup = loadSetup();

    Blob blob;
    blob.bytes[] = 0;

    auto commitment = setup.blobToKzgCommitment(blob);
    auto proof = setup.computeBlobKzgProof(blob, commitment);

    const valid = setup.verifyBlobKzgProofBatch([blob], [commitment], [proof]);
    assert(valid, "Batch proof should be valid");
}

/// Test empty batch verification
unittest
{
    auto setup = loadSetup();

    Blob[] blobs;
    Bytes48[] commitments;
    Bytes48[] proofs;

    const valid = setup.verifyBlobKzgProofBatch(blobs, commitments, proofs);
    assert(valid, "Empty batch should be valid");
}

/// Test EIP-7594 cells and proofs
unittest
{
    auto setup = loadSetup();

    Blob blob;
    blob.bytes[] = 0;

    const result = setup.computeCellsAndKzgProofs(blob);
    assert(result.cells.length == CELLS_PER_EXT_BLOB);
    assert(result.proofs.length == CELLS_PER_EXT_BLOB);
}

/// Test loading trusted setup from an invalid path
unittest
{
    bool threw = false;
    try
    {
        auto setup = TrustedSetup.fromFile("/nonexistent/path/trusted_setup.txt");
    }
    catch (KzgException e)
    {
        threw = true;
        assert(e.errorCode == C_KZG_BADARGS);
    }
    assert(threw, "Should have thrown KzgException");
}

/// Test that batch verification fails on length mismatch
unittest
{
    auto setup = loadSetup();

    Blob blob;
    blob.bytes[] = 0;

    auto commitment = setup.blobToKzgCommitment(blob);
    auto proof = setup.computeBlobKzgProof(blob, commitment);

    bool threw = false;
    try
    {
        // proofs array is empty while blobs and commitments have 1 element
        setup.verifyBlobKzgProofBatch([blob], [commitment], []);
    }
    catch (AssertError)
    {
        threw = true;
    }
    assert(threw, "Should have thrown on length mismatch");
}

/// Test constants
unittest
{
    assert(BYTES_PER_BLOB == 131_072);
    assert(BYTES_PER_COMMITMENT == 48);
    assert(BYTES_PER_PROOF == 48);
    assert(BYTES_PER_FIELD_ELEMENT == 32);
    assert(FIELD_ELEMENTS_PER_BLOB == 4096);
    assert(BYTES_PER_CELL == 2048);
    assert(FIELD_ELEMENTS_PER_CELL == 64);
    assert(CELLS_PER_BLOB == 64);
    assert(CELLS_PER_EXT_BLOB == 128);
}
