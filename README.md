<h1 align="center"> Baby Woolball - A name system for humans </h1> <br>
<p align="center">
  <img alt="Baby Woolball Mascot" src="https://neiman.co.il/images/babywoolball_mascot.jpg" width="300">
</p>

Baby Woolball is a blockchain name system where only humans can have names. It helps people know if they talk with humans or AIs online.

To have a Baby Woolball name people need to submit a [zk proof of personhood](#zk-proof-of-personhood). With ZK users can keep their privacy while still being able to prove qualitative claims about themselves, such as humanity or proof of age. 

Baby Woolball names are of the form `neiman#`, where the `#` symbolizes the name belonging to "Baby Woolball".

## How to use Baby Woolball
To use Baby Woolball users first register a name and set their private keys to it. The name is disabled at first. Users have 30 days to submit proof of humanity to enable it.

The owner of the Baby Woolball contract sets a Merkle tree root of the trusted entities for creating proof of personhood certificates. The public keys of the entities are the leaves of the Merkle tree.

The user needs to get a proof of personhood certificate from one of those entities. These certificates are created with Safecat. Using this certificate, the users create a zk-certificate stating that they are human. The user then submits the zk-certificate to Baby Woolball to enable the program.

The certificate standard of Baby Woolball also includes a "birthdate" field, enabling in the future to also post proof of age.

## Tech stack
Woolball is built using Noir, Rust, and Solidity.

**Rust**. Rust is used to generate signed certificates for Noir to use. The certificates are hashed using Poseidon function and signed with EdDSA signatures on the Baby Jubjub curve. These cryptographic tools fit well with the current requirements of Noir. 

The signatures are done with a CLI cryptographic tool I previously published called "Safecat". I created a [special branch of Safecat for the Hackathon](https://github.com/HastilyConceivedCreatures/safecat/tree/feature/certPubkeyName) with extra functionality needed to generate the certificates for Baby Woolball.

At the first version, the certificates were json strings. This turned out to be problematic with Noir which is both not good with manipulating string and is very slow with it. In the final version, the certificates are an array of BN254 curve elements, a format that integrates perfectly with Noir needs.

**Noir**. Noir is used to create zk proofs of personhood using the certificates. Noir also generates a Solidity verifier to be used to verify the proofs on-chain. See the Noir program [here](https://github.com/eyalron33/babywoolball/tree/main/noir/verify-1-human-certificate-for-pubkey-name-address).

**Solidity**. The name system is written in Solidity. It is a new code base, not a fork of any existing name system.

## zk proof of personhood
A proof of personhood is a digital certificate attesting that someone is a unique human person. Such certificates are officially issued by organizations like [Worldcoin](https://worldcoin.org/) or [CAceert](http://www.cacert.org/), but can also be unofficially interpreted by methods of collecting stamps s.a [Gitcoin Passport](https://passport.gitcoin.co/).

However, to use those 

## Related projects
[ZkPass](https://zkpass.org/) is a project generating zk proof of personhood based on stamps. Their protocol could be adjusted to verify Woolball name, though it requires internal work of their team since certificates are issued for a blockchain address, while Woolball requires issuance for name and an outside public key.
