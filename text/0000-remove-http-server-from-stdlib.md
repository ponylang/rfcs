- Feature Name: remove-http-packages-from-stdlib
- Start Date: 2018-01-13
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Remove the HTTP server and client that are currently in the standard library. Place them in their own repository under the ponylang organization.

# Motivation

The initial HTTP server that was included in the standard library was done as an example/proof of concept. It's not designed to be high performance or be particularly easy to work with. The current HTTP server is based off of that one. It was an improvement in some ways but:

- It still has poor performance characteristics
- Its API is still strongly based on the original version with its poor API ergonomics

We, as a community, want a great HTTP server that we can use. Having a middling HTTP server in the standard library doesn't help the cause. It discourages others from potentially implementing their own. Further, folks will look at the various decisions made designing said HTTP server and assume that it is how you should write Pony code. Given its performance issues, I don't think we want folks copying it.

There are many things that we can say really should be in a standard library. Strings, Arrays, Maps and other data structures that we want everyone to build on to make interoperation between libraries certainly fit the bill. The argument for having an HTTP server in the standard library is much weaker.

The same general argument applies to the HTTP client. The API ergonomics are poor and a regular source of frustration for new users. By removing it from the standard library, we would be encouraging folks to create their own competing HTTP clients.

# Detailed design

Move the following to their own repository "example-http-server" under the Ponylang organization.

- packages/net/http/*
- examples/httpget
- examples/httpserver

Update examples/main.pony to not include:

```
use ex_httpget = "httpget"
use ex_httpserver = "httpserver"
```

In the new repo, the README for the http server and client, should make its lineage known. It should indicate that they are not an exemplar of how you would write high performance code. They can be used, with caveats about API ergonomics and performance. The README should strongly indicate that the Pony core team encourages community members to create their own, better HTTP server(s) and client(s) and get them adopted by the community at large.

# How We Teach This

The deprecation should be "taught" to folks via:

- a note in last week in Pony about this RFC being created (this is standard)
- a call out in release notes for release this change occurs in.

# How We Test This

CI should pass for ponyc repo after the change is made. CI should be set up for the new repo to run HTTP server tests and examples to verify that everything was correctly moved.

# Drawbacks

This is a breaking change for anyone using the HTTP server or client. They will have to go through a small upgrade to use Pony stable to fetch the new dependency from a new location. Additionally, package names will change as it will no longer be `net/http`. That package name makes sense in the standard library, it doesn't as a standalone.

# Alternatives

We could leave in the standard library and incur the drawbacks that come from people thinking these is the officially sanctioned HTTP libraries that we as a community want to go forward with.

# Unresolved questions

There are details of organization in the new repository etc that have been left to the implementer.
