/* Verifies that a person has a valid proof of humanity.
 * The certificate is issued to a public-key and name combination.
 * The prover signs the certificates (to show they hold the public key).
 * The prover specifies the EVM address holding the name to ensure the proof will only be used for this address.
 * Is is verified that the certificate is signed by a trusted entity. The set of trusted entity is represented by a merkel root with depth 2.
 * See full details in the Readme.
 * Nargo version = 0.29.0 noirc = 0.29.0+a5b7df12faf9d71ff24f8c5cde5e78da44558caf
 */

mod data_processing;

use data_processing::bytes_to_fields;
use dep::std;

// Struct representing a person, with x and y coordinates for a public key
struct Person {
    x: Field,
    y: Field,
}

// Struct representing a digital signature, with components s, rx, and ry
struct Signature {
    s: Field,
    rx: Field,
    ry: Field
}

struct Certificate {
    person: Person,
    name: Field, // blockchain names are uint256 which we represent as Field in Noir
    expiration: Field,
    cert_type: Field,
    birthdate: Field
}

// Struct representing a hash path in a Merkle tree with depth 2
struct HashPath {
    path: [Field; 2],
    index: Field
}

impl Certificate {
    // Method to hash the certificate data using the Poseidon hash function
    fn hash(self) -> Field {
        let certificate_as_array : [Field; 6] = [self.person.x, self.person.y, self.name, self.expiration, self.cert_type, self.birthdate];
        let certificate_hash = std::hash::poseidon::bn254::hash_6(certificate_as_array);

        certificate_hash
    }
}

// Function to check that a person has a type 1 certificate signed by two signers
// It takes the following arguments:
// - person: The person whose certificate is being verified
// - trust_kernel_root: The root of the trust kernel Merkle tree
// - last_checked_timestamp: The timestamp in which we check that the certificate is still valid
// - expiration: The expiration date of the certificate
// - birthdate: The person's birthdate
// - signers: An array of two persons representing the signers
// - signature: An array of two signatures corresponding to the signers
// - signers_hash_path: An array of two HashPath structs representing the hash paths for the signers
fn main(
    person: pub Person,
    trust_kernel_root: pub Field,
    last_checked_timestamp: pub Field,
    person_address: pub Field, // We treat EVM addresses as Field
    name: pub Field, // blockchain names are uint256 which we represent as Field in Noir
    expiration: Field,
    birthdate: Field,
    own_signature: Signature, // Signature of the peron owning the certificate, proving they generated the proof
    signer: Person,
    signature: Signature,
    signer_hash_path: HashPath
) {
    // Verify the person signed the address to signal that it belongs to them
    let verify_own_signature = dep::std::eddsa::eddsa_poseidon_verify(
        person.x,
        person.y,
        own_signature.s,
        own_signature.rx,
        own_signature.ry,
        person_address // We treat EVM addresses as Field
    );

    // Verify that the current timestamp is before the certificate expiration date
    assert(last_checked_timestamp.lt(expiration));

    // Create a Certificate struct with type 2 (birth certificate for addresses)
    let certificate = Certificate { person, name, expiration, cert_type: 1, birthdate };

    // Verify signers signatures

    let verify_signer_signature = dep::std::eddsa::eddsa_poseidon_verify(
        signer.x,
        signer.y,
        signature.s,
        signature.rx,
        signature.ry,
        certificate.hash()
    );

    // Verify that both signatures are correct
    assert(verify_own_signature);
    assert(verify_signer_signature);

    // Calculate the Merkle root using the first signer hash path
    let leaf_signer : Field = std::hash::pedersen_hash([signer.x, signer.y]);

    // Calculate the Merkle root using the second signer hash path
    let merkel_root = std::merkle::compute_merkle_root(leaf_signer, signer_hash_path.index, signer_hash_path.path);

    // Verify that the calculated Merkle roots match the trust kernel root
    assert(merkel_root == trust_kernel_root);
}

// convers a message to an array of Field
pub fn message_to_fields<N, M>(msg: str<N>) -> ([Field; M], u32) {
    bytes_to_fields(msg.as_bytes())
}
