/**
 * Simple example demonstrating the c-kzg-4844 D bindings.
 */
import ckzg;
import std.stdio : writeln, writefln;
import std.file : thisExePath;
import std.path : dirName, buildPath;

void main()
{
    // Get the path to trusted_setup.txt relative to the executable
    string exeDir = dirName(thisExePath());
    string setupPath = buildPath(exeDir, "..", "..", "..", "src", "trusted_setup.txt");

    writeln("Loading trusted setup from: ", setupPath);

    // Load trusted setup from file
    auto setup = TrustedSetup.fromFile(setupPath);

    // Create a sample blob (all zeros for demonstration)
    Blob blob;
    blob.bytes[] = 0;

    // Compute KZG commitment
    auto commitment = setup.blobToKzgCommitment(blob);
    writeln("Commitment: ", commitment.toHex());

    // Compute blob KZG proof
    auto proof = setup.computeBlobKzgProof(blob, commitment);
    writeln("Proof: ", proof.toHex());

    // Verify the proof
    const valid = setup.verifyBlobKzgProof(blob, commitment, proof);
    writefln("Proof valid: %s", valid);

    // EIP-7594: Compute cells and proofs
    auto cellsAndProofs = setup.computeCellsAndKzgProofs(blob);
    writefln("Number of cells: %d", cellsAndProofs.cells.length);
    writefln("Number of proofs: %d", cellsAndProofs.proofs.length);

    writeln("Done!");
}
