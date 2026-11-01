# OpenCode update retrospective

This note records the OpenCode v1/v2 update exercise on 2026-10-31 and the
checks that should keep its fixes from regressing.

## Outcome

- OpenCode v1 moved from 1.19.4 to 1.19.5.
- OpenCode v2 moved from 2.1.4 to 2.2.5.
- Both generated dependency locks had unchanged native payload inventories.
- Both packages built successfully. The v1 build's package smoke check passed;
  explicit `--version` checks passed for both launchers. The v2 `--version` and
  `--help` checks required isolated writable XDG/HOME directories because the
  application otherwise attempted to write logs under the user's home.
- The updater manifest validation passed for all 39 configured packages.

## What required intervention

1. The first lock generation attempted to fetch the entire Bun dependency
   closure again. Most of the closure had identical cache labels and source
   URLs to the previous lock. The locker now reuses a previous fixed hash only
   when both values match; changed labels or URLs still fetch and hash the
   source again.
2. OpenCode v1 declares `@opencode-ai/client` as a local `file:` tarball. Bun
   can install it, but a generated Guix origin needs an immutable source URL.
   The Bun adapter now discovers local `.tgz`/`.tar.gz` dependencies inside the
   extracted source and maps them to raw GitHub URLs at the pinned tag. Conflicting
   mappings and files outside the source tree are rejected/ignored rather than
   silently generating an ambiguous URL.
3. Generated locks are large and can change substantially even when the
   package's native payload inventory stays stable. Review the package diff,
   native inventory report, and build result together before applying an
   update.

## Regression coverage

`make update-test` runs the update framework's Python and Guile unit suites.
The Bun adapter tests now cover:

- wiring the prior lock into lock generation;
- parsing a generated lock and reusing a digest only for the same label and URL;
- mapping an in-tree `file:` tarball to its pinned immutable source URL;
- ignoring missing tarballs and directory dependencies.

The end-to-end acceptance sequence for a future OpenCode release is:

```sh
make update-bun PACKAGE=opencode-v1 VERSION=<version>
make update-bun PACKAGE=opencode-v2 VERSION=<version>
make update-validate
make build EXPR='(@ (under-sea packages opencode-v1) opencode-v1)' BUILD_FLAGS='--no-substitutes --cores=4'
make build EXPR='(@ (under-sea packages opencode-v2) opencode-v2)' BUILD_FLAGS='--no-substitutes --cores=4'
```

After applying, check the CLI version in an isolated writable home and compare
the native payload inventory. A VM integration test was not part of this
exercise; package build plus CLI smoke checks are the evidence recorded here.
