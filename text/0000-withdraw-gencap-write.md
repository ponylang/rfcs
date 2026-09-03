- Feature Name: withdraw-gencap-write
- Start Date: 2026-09-03
- RFC PR: https://github.com/ponylang/rfcs/pull/NNNN
- Pony Issue: https://github.com/ponylang/ponyc/issues/2060

# Summary

Withdraw RFC 43, "gencap-write". The original RFC stays in the repository as a historical record but is no longer an accepted proposal.

# Motivation

RFC 43 was accepted in 2017 and has never been implemented. The original author has since recommended against pursuing the feature, noting that the gencap didn't solve their problem and that the subtle edge cases in generic subtyping make adding new generic caps risky.

No one has needed this feature in the nine years since it was accepted. Leaving it on the accepted list implies the feature is wanted and would be merged if implemented, neither of which is true.

# Detailed design

Add a note to the top of `text/0043-gencap-write.md` recording that the RFC has been withdrawn and pointing to this RFC.

Close ponyc issue #2060 with a comment pointing at this RFC.

# How We Teach This

Nothing to teach. RFC 43 was never implemented and no user code depends on it.

# How We Test This

Nothing to test. No code changes are involved.

# Drawbacks

None. RFC 43 was never implemented and no work is in progress against it.

# Alternatives

Leave RFC 43 on the accepted list. This keeps an "accepted" RFC that no one wants implemented and whose author recommends against it.

# Unresolved questions

None.
