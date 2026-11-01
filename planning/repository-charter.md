# under-sea repository charter

Status: current project policy, adopted 2026-11-01.

This document defines what the repository is for and what “supported” means.
The [update manifest](update-manifest.json) and its generated report are the
source of truth for package inventory and update levels. `STATUS.md` is the
delivery and limitation record. Historical plans describe how the repository
got here; they do not override this charter or the live manifest.

## Positioning

under-sea is a Guix channel for an individual or small team that wants a
curated set of AI agent and developer tools, networking software, and selected
desktop/service packages with explicit Guix integration. Its distinguishing
qualities are fixed source inputs, builds that do not need network access,
declared exceptions where source builds are not possible, and package-level
smoke or system tests where practical.

This is a curated channel, not a promise to package every upstream release, a
general-purpose replacement for Guix, or a guarantee that every package is
equally stable. Packages remain in scope when they serve an actual repository
use case and their maintenance cost is understood. A package can be retained
at a lower automation level, marked experimental, frozen, or removed when it
no longer meets that bar.

## Update and support policy

- Versions are reviewed against upstream releases; they are not bumped merely
  because a newer tag exists. Security fixes and supported-use cases take
  priority, subject to compatibility and verification.
- **L0** records an explicit manual or source-unavailable boundary.
- **L1** detects and reports upstream changes.
- **L2** prepares source pins and hashes and runs the declared package gate;
  dependency and compatibility changes remain human-reviewed.
- **L3** also regenerates or verifies the dependency lock and runs declared
  offline, host, integration, or VM checks. It does not imply automatic
  compatibility approval.
- **L4 automatic merge is disabled.** Precompiled, proprietary, native-payload,
  multi-upstream, and major compatibility changes require human review.
- A package may stay below L3 if it has no deterministic lock/update path or
  the cost of verification exceeds the value. The reason must be visible in
  the manifest or status record.
- A version is supported only to the extent of the recorded checks. Hardware,
  credentials, external services, and user-supplied proprietary archives are
  separate prerequisites and must not be implied by a successful build.

## Completion standard

The repository is in a healthy, maintainable state when:

1. A new consumer can add the authenticated channel, find the package
   expression, and follow a tested install/use path from the documentation.
2. Every user-facing package is in the update manifest or an explicit
   exemption, with its upstream, update level, lock policy, and verification
   commands accurately described.
3. Offline source/build guarantees and all precompiled or proprietary
   exceptions are auditable; no documentation claims a stronger guarantee
   than the evidence supports.
4. The regular packaging and update checks pass, and each known failure or
   skip has an owner-independent reproduction command and a concrete next
   action or explicit external prerequisite.
5. Documentation has one live source for inventory and update coverage;
   dated snapshots and completed plans are labeled historical.

Completion does not require every package to be L3, every optional feature to
be packaged, or every external/device test to pass on every host. It requires
clear scope, trustworthy evidence, and explicit boundaries.

## Current work order

1. Keep the manifest audit, update report, packaging checks, and package-level
   tests authoritative; update prose from those sources rather than hand-
   maintaining a second inventory.
2. Keep the Hermes gateway VM test in the service verification matrix; its
   offline end-to-end path now passes 7/7 assertions.
3. Reconcile status and historical planning documents when implementation
   changes; retain detailed provenance files that are build inputs.
4. Promote update levels only when their next-level exit checks are in place.
   The current report has no eligible L1 promotion and one L2 package;
   Agent Cat remains L2 until recurring update demand justifies a deterministic
   Hackage-family adapter and regression gate. The package maturity review
   records the scope and constraints of all 45 inventory entries. L0 exceptions
   remain policy-gated.

Run `guile --no-auto-compile -L scripts/update -s scripts/update/report.scm`
for current counts. The report is a snapshot of the checked-in manifest, not
a measure of upstream freshness or package runtime quality.
