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

This package will use the OpenSSL crypto library through the C FFI. The following API will be used:

- HashFunc

    interface providing a hash() function that produces a fixed-length byte sequence based on the input sequence.
    
    Example use:
    	
    	SHA256.hash([101 120 97 109 112 108 101])
    Return value:
    	
        [80 216 88 224 152 94 204 127 96 65 138 175 12 197 171 88 127 66 194 87 10 136 64 149 169 232 204 172 208 246 84 92]


- ConstantTimeCompare
 
    primitive where the apply function takes in two byteseq arguments and returns a Bool, true if they are equal and false otherwise.

    Example use:
    	
    	let s1 = [U8(1), U8(2), U8(3), U8(4), U8(5)]
    	let s2 = [U8(5), U8(4), U8(3), U8(2), U8(1)]
    	ConstantTimeCompare(s1, s1) // returns true
    	ConstantTimeCompare(s1, s2) // returns false
   
   see also: [Golang implementation](https://golang.org/src/crypto/subtle/constant_time.go?s=490:531#L2)

# How We Teach This

This package should be used with some knowledge of basic concepts such as:

- Hash functions - can be used to calculate the checksum of some data. It can be used in digital signatures and authentication. e.g. SHA-256 or MD5
- Constant time comparison - used to prevent [timing attacks](http://crypto.stanford.edu/~dabo/papers/ssl-timing.pdf) with the use of constant-time algorithms

# Drawbacks

None

# Alternatives

The impact of not providing cryptographic security to various Pony applications would create substantial vulnerabilities that could otherwise be avoided.

# Unresolved questions

None
