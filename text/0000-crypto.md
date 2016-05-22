- Feature Name: crypto
- Start Date: 2016-05-22
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The addition of a Cryptography package to the stdlib would provide necessary features to Pony applications, such as secure communications and password protection. The package will include a variety of common cryptographic algorithms such as SHA-1, SHA-256, MD5, DES, RSA, etc.

# Motivation

Cryptography is a vital tool in the areas of authentication, confidentiality, data integrity, and nonrepudiation.

# Detailed design

*Security must be the first priority of this package.*

The package will include the following interfaces:

- HashFunc

	provides a hash() function that produces a fixed-length byte sequence based on the input sequence.
    
    Example use:
    	
    	SHA256.hash([101 120 97 109 112 108 101])
    Return value:
    	
        [80 216 88 224 152 94 204 127 96 65 138 175 12 197 171 88 127 66 194 87 10 136 64 149 169 232 204 172 208 246 84 92]

- Cypher

	provides encrypt() and decrypt() functions that both produce a byte sequence from the input sequence. If the result of encrypting a given byte sequence is then passed into the decrypt function, the result should be the given byte sequence.
    
    primitives must be provided for the various Block cypher modes of operation: CBC, ECB, CFB, OFB, and CTR. These will be passed into the constructors of any block cyphers along with the encryption key.
    
    Example use:
    	
        let des = DES("01234567", ECB)
        let enc = des.encrypt("abcdefgh")
        des.decrypt(enc) // returns "abcdefgh"

- PublicKey

	Implemented as primitives that provide a generate() function which produces a Key object. The generate function will take a cryptographically secure pseudorandom number generator.
    
    The Key object will have the ability to encrypt data, decrypt data, sign data, verify a signature, and create a public key.
    
    Example use:
    	
        let rand = CryptoRandom()
        let key = RSA.generate(rand)
        let enc = key.encrypt("abcdefgh")
        key.decrypt(enc) // returns "abcdefgh"
        
        hash = SHA256.hash("abcdefgh")
        let signature = key.sign(hash, "")
        key.verify(hash, signature) // returns true
        
	
The package must also allow the user to do the following:

- Perform constant time comparisons of byte sequences
- Create a cryptographically secure pseudorandom number generators


# How We Teach This

This package should be used with some knowledge of basic concepts such as:

- Hash functions - can be used to calculate the checksum of some data. It can be used in digital signatures and authentication. e.g. SHA-256 or MD5
- Encryption algorithms - take some byte sequence as input and produce a cipher byte sequence using a variable key. You have 2 types of ciphers: block and stream.
  - Block ciphers work on blocks of a fixed size (8 or 16 bytes). e.g. DES
  - Stream ciphers work byte-by-byte. Knowing the key, you can decrypt the cipher. e.g. XOR
- Public-key algorithms - there are two different keys: one to encrypt and one to decrypt. You only need to share the encryption key and only you can decrypt the message with your private decryption key. e.g. RSA

# Drawbacks

None

# Alternatives

The impact of not providing cryptographic security to various Pony applications would create substantial vulnerabilities that could otherwise be avoided.

# Unresolved questions

None
