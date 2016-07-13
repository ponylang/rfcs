- Feature Name: file_naming_guidelines
- Start Date: 2016-06-08
- RFC PR: https://github.com/ponylang/rfcs/pull/11
- Pony Issue: https://github.com/ponylang/ponyc/issues/1024

# Summary

Add guidelines for naming Pony source files in the standard library.

# Motivation

We have style guidelines for Pony source code in the standard library, but we don't yet have any guidelines for naming Pony source files. Having a consistent, reproducible scheme for naming files is a natural extension of code style, and key to good organization.

# Detailed design

I propose the following rules for naming Pony source code files in the standard library:

- The *file name* of Pony source files should be based on the name of the *principal type* defined in that file.
    + The *principal type* in a file is the type that makes up the bulk of the significant lines of code in the file or is conceptually more important or fundamental than all other types in the file. For example, if a file defines a trait type and a group of small class types that all provide that trait, then the trait type should be considered the *principal type*.
    + If there are multiple types defined in the file which all have equal significance and a shared name prefix, then the shared prefix should be used as the *principal type name*. For example, a file that defines `PacketFoo`, `PacketBar`, and `PacketBaz` types should use `Packet` as the *principal type name*, even if no `Packet` type is defined.
    + If there are multiple significant types defined in the file which do not have a shared name prefix, then this should be taken as a hint that these types should probably be defined in separate files instead of together in one file.
- The *file name* should be directly derived from the *principal type name* using a consistent reproducible scheme of case conversion.
    + The *file name* should be the "snake case" version of the *principal type name*. That is, each word in the *principal type name* (as defined by transitions from lowercase to uppercase letters) should be separated with the underscore character (`_`) and lowercased to generate the *file name*. For example, a file that defines the `ContentsLog` type should be named `contents_log.pony`.
    + If the *principal type* is a private type (its name beginning with an underscore character), then the *file name* should also be prefixed with an underscore character to highlight the fact that it defines a private type. For example, a file that defines the `_ClientConnection` type should be named `_client_connection.pony`.
    + If the *principal type* name contains an acronym (a sequence of uppercase letters with no lowercase letters between them), then the entire acronym should be considered as a single word when converting to snake case. Note that if there is another word following the acronym, its first letter will also be uppercase, but should not be considered part of the sequence of uppercase letters that form the acronym. For example, a file that defines the `SSLContext` type should be named `ssl_context.pony`.

# How We Teach This

A clear listing of the naming rules should be added to `CONTRIBUTING.md` of the `ponyc` repository, and we should reference this text when a reviewing a pull requests with new code.

# Drawbacks

None.

# Alternatives

Many files currently use a simple lowercasing transformation of type names to file names. This is problematic because the transformation loses information about the separations between words that is present in the type names. For example, when a file is named `contentslog.pony`, it's not immediately clear to human or machine whether the type defined within is `ContentsLog` or `ContentSlog`. Using the "snake case" transformation as defined in this RFC is a lossless transformation that can be reversed and repeated by human or machine.

A few files in the standard library use a dash character (`-`) instead of an underscore (`_`) between words in the file name. Using an undescore as in "snake case" is more consistent with idiomatic Pony style, because this style is used to represent lowercase identifiers (method, field, and local reference names) in idiomatic Pony code style.

# Unresolved questions

None.
