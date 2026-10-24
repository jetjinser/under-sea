# Channel dependency pins

## Current state

`.guix-channel` declares two dependencies with fixed commits:

- `nonguix` at `cf5e3b8f9f6a2bc8cfc2039cb5153d625a08da6b`
- `guix-science-nonfree` at `b9cc745a1d756cf94de355a12d5742c71230fe7d`

The build lock in `channels.scm` currently selects `nonguix` at
`47c20df59dd9f27c9154ef20a81d383a19d4ad7f`, while the README and STATUS still
say `cf5e3b8f`. The `.guix-channel` pin is therefore older than the build lock.
When `guix pull` resolves the transitive dependency, the explicit dependency
commit can take precedence over an unpinned top-level channel of the same name.
Since `cf5e3b8` is behind the installed `47c20df` revision, this can trigger the
forward-only downgrade refusal. Guix resolves one revision per channel name in
a pull; it does not keep two simultaneous `nonguix` revisions as Nix flakes
can keep distinct inputs.

The two dependencies are used by package definitions:

- `hermes-electron.scm` imports `(nongnu packages electron)`.
- `strata.scm` imports `(guix-science-nonfree packages cuda)` for the CUDA
  variant.

## Suggested maintenance

Treat `.guix-channel` as the declaration of required channel dependencies, and
`channels.scm` as the tested, reproducible build lock. Remove the fixed commit
from the `nonguix` dependency in `.guix-channel` so a consumer's top-level
channel selection is not unexpectedly forced backwards. Keep the tested
`nonguix` revision pinned in `channels.scm`, and update the README and STATUS
to match that lock.

Keep `guix-science-nonfree` fixed at `b9cc745` for now: it supplies the CUDA
toolkit used by `strata-cuda`. Change or remove that pin only as part of a
coordinated channel refresh that updates the build lock and verifies the CUDA
package. A consumer using an unpinned channel set should be aware that this
dependency remains intentionally fixed until that refresh.

Guix's channel-dependency documentation says dependencies are fetched
automatically and their modules are made available to the channel. It
recommends minimizing dependencies, especially on channels the author does not
control. An omitted dependency `commit` leaves revision selection to the
consumer's channel set; pinning a dependency in `.guix-channel` expresses a
compatibility constraint and can override that choice. See the Guix manual,
“Declaring Channel Dependencies”.

This is a maintenance note only; no channel or package configuration is
changed here.
