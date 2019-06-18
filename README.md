

# Pony RFCs

Many changes, including bug fixes and documentation improvements can be implemented and reviewed via the normal GitHub pull request workflow.

Some changes though are "substantial", and we ask that these be put through a bit of a design process and produce a consensus among the Pony community and committers.

The "RFC" (request for comments) process is intended to provide a consistent and controlled path for new features to enter the language and standard libraries, so that all stakeholders can be confident about the direction the language is evolving in.

## When you need to follow this process

You need to follow this process if you intend to make "substantial" changes to Pony. What constitutes a "substantial" change is evolving based on community norms and varies depending on what part of the ecosystem you are proposing to change, but may include the following.

   - Any semantic or syntactic change to the language that is not a bugfix.
   - Removing language features.
   - Changes to the interface between the compiler and libraries, including lang items and intrinsics.
   - Additions to `stdlib`.

Some changes do not require an RFC:

   - Rephrasing, reorganizing, refactoring, or otherwise "changing shape does not change meaning".
   - Additions that strictly improve objective, numerical quality criteria (warning removal, speedup, better platform coverage, more parallelism, trap more errors, etc.)
   - Additions only likely to be _noticed by_ other developers-of-pony,
invisible to users-of-pony.

What is a bugfix?

Bugfixes do not have to go through the RFC process. The definition of "bugfix" is still evolving. Some things we consider to be bug fixes:

   - Fixing performance issues that are found in existing implementations. 
   - Principal of least surprise bugs. Sometimes, we design APIs that surprise the user and don't operate as they would expect. We consider addressing these to fall under the category of "bugfix".

As we move forward, we will add more rules to our list of "items that don't need an RFC". If there is doubt about whether a change/addition requires an RFC, the issue will be resolved by a quorum vote of active committers to the project.

If you submit a pull request to implement a new feature without going
through the RFC process, it may be closed with a polite request to
submit an RFC first. If you believe that your PR falls under one the exemptions above, please raise that in the initial PR.

## Before creating an RFC

A hastily-proposed RFC can hurt its chances of acceptance. Low quality proposals, proposals for previously-rejected features, or those that don't fit into the near-term roadmap, may be quickly rejected, which can be demotivating for the unprepared contributor. Laying some groundwork ahead of the RFC can make the process smoother.

Although there is no single way to prepare for submitting an RFC, it is generally a good idea to pursue feedback from other project developers beforehand, to ascertain that the RFC may be desirable: having a consistent impact on the project requires concerted effort toward consensus-building.

The most common preparations for writing and submitting an RFC include talking the idea over at the weekly Pony sync meeting or discussing on the pony+dev mailing.

As a rule of thumb, receiving encouraging feedback from long-standing project developers.

## What the process is

In short, to get a major feature added to Pony, one must first get the RFC merged into the RFC repo as a markdown file. At that point the RFC is 'active' and may be implemented with the goal of eventual inclusion into Pony.

* Fork the RFC repo http://github.com/ponylang/rfcs
* Copy `0000-template.md` to `text/0000-my-feature.md` (where 'my-feature' is descriptive. don't assign an RFC number yet).
* Fill in the RFC. Put care into the details: RFCs that do not present convincing motivation, demonstrate understanding of the impact of the design, or are disingenuous about the drawbacks or alternatives tend to be poorly-received.
* Submit a pull request. As a pull request the RFC will receive design feedback from the larger community, and the author should be prepared to revise it in response.
* Build consensus and integrate feedback. RFCs that have broad support are much
more likely to make progress than those that don't receive any comments. 
* We may request that the author and/or relevant stakeholders to get together to discuss the issues in greater detail.
* The Pony committers will discuss the RFC PR, as much as possible in the comment thread of the PR itself. Offline discussion will be summarized on the PR comment thread.
* You can make edits, big and small, to the RFC to clarify or change the design, but make changes as new commits to the PR, and leave a comment on the PR explaining your changes. Specifically, do not squash or rebase commits after they are visible on the PR.
* Once both proponents and opponents have clarified and defended positions and the conversation has settled, the RFC will enter its *final comment period* (FCP). This is a final opportunity for the community to comment on the PR and is a reminder for all committers to be aware of the RFC. It is up to the author of the RFC to decide when the RFC officially enters the *final comment period*. Once they have indicated to repository maintainers that they wish for the RFC to move into the *final comment period*, the *final comment period* tag will be added to PR and an email with information about the PR will be sent to the pony+dev@groups.io development mailing list.
* The FCP lasts one week. It may be extended if consensus between committers cannot be reached. At the end of the FCP,  the committers will either accept the RFC by merging the pull request, assigning the RFC a number (corresponding to the pull request number), at which point the RFC is 'active', or reject it by closing the pull request. Currently, consensus means a quorum of active core developers agree to adopt the RFC in principle.

## The RFC life-cycle

Once an RFC becomes active then authors may implement it and submit the feature as a pull request to the Pony repo. Being 'active' is not a rubber stamp, and in particular still does not mean the feature will ultimately be merged; it does mean that in principle all the major stakeholders have agreed to the feature and are amenable to merging it.

Furthermore, the fact that a given RFC has been accepted and is 'active' implies nothing about what priority is assigned to its implementation, nor does it imply anything about whether a Pony developer has been assigned the task of implementing the feature. While it is not *necessary* that the author of the RFC also write the implementation, it is by far the most effective way to see an RFC through to completion: authors should not expect that other project developers will take on responsibility for implementing their accepted feature.

Modifications to active RFC's can be done in follow-up PR's. We strive to write each RFC in a manner that it will reflect the final design of the feature; but the nature of the process means that we cannot expect every merged RFC to actually reflect what the end result will be at the time of the next major release.

In general, once accepted, RFCs should not be substantially changed. Only very minor changes should be submitted as amendments. More substantial changes should be new RFCs, with a note added to the original RFC. Exactly what counts as a "very minor change" is up to the committers to decide. 

## Reviewing RFC's

While the RFC PR is up, we may schedule meetings with the author and/or relevant stakeholders to discuss the issues in greater detail. A summary from the meeting will be posted back to the RFC pull request.

We will make final decisions about RFCs after the benefits and drawbacks are well understood. These decisions can be made at any time. When a decision is made, the RFC PR will either be merged or closed.

## Implementing an RFC

Some accepted RFC's represent vital features that need to be implemented right away. Other accepted RFC's can represent features that can wait until some arbitrary developer feels like doing the work. Every accepted RFC has an associated issue tracking its implementation in the Pony repository; thus that associated issue can be assigned a priority via the triage process that the team uses for all issues in the Pony repository.

The author of an RFC is not obligated to implement it. Of course, the RFC author (like any other developer) is welcome to post an implementation for review after the RFC has been accepted.

If you are interested in working on the implementation for an 'active' RFC, but cannot determine if someone else is already working on it, feel free to ask (e.g. by leaving a comment on the associated issue).

**Pony's RFC process owes its inspiration to the [Rust RFC process]** additionally, we also borrowed from the [Ember RFC process]. Thanks folks.

[Rust RFC process]: https://github.com/rust-lang/rfcs
[Ember RFC process]: https://github.com/emberjs/rfcs
