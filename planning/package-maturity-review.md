# Package maturity review

Review date: 2026-11-01. Inventory and update levels are taken from
`planning/update-manifest.json` and `planning/update-exemptions.json` (39
manifest entries plus 6 explicit L0 exceptions). This is a scope and evidence
review, not a fresh rebuild of all 45 packages. “Maintained” means the item is
within the current maintained set and has the declared update/verification
path; it does not claim broad runtime validation. “Constrained” records a
known proprietary, prebuilt, hardware, or native-payload boundary. “Trial” is
kept for an item whose maintenance is real but whose ongoing user value should
be rechecked before investing in more automation.

No package is designated frozen or removed in this review: the current records
do not establish that any package has become unused or unmaintainable. Revisit
that decision when actual use, upstream health, or maintenance cost changes.

| Item | Update level | Review state | Next action |
|---|---:|---|---|
| adsk-licensing | L0 | Constrained | Keep user-supplied proprietary archive and platform/license limits explicit. |
| agent-browser | L3 | Maintained | Keep the browser integration gate and external browser requirements visible. |
| agent-cat | L2 | Trial | Retain L2; gather use evidence and only build a Hackage-family updater if repeated updates justify it. |
| bun-for-hermes | L0 | Constrained | Keep bootstrap binary provenance and interpreter-only patch boundary reviewed. |
| bun-for-opencode | L0 | Constrained | Same bootstrap policy; track compatibility with both OpenCode lines. |
| camofox-browser | L3 | Constrained | Review browser/controller compatibility and native payload changes on updates. |
| codex | L3 | Maintained | Keep CLI, code-mode and voice integration checks aligned with the packaged features. |
| codex-base | L3 | Maintained | Preserve the offline Cargo lock and release/execpolicy smoke. |
| codex-code-mode-host | L3 | Maintained | Keep the local V8 host check; rebuild when Rust/LLVM channel inputs change. |
| codex-sdk | L3 | Maintained | Keep TypeScript lock and ESM import smoke. |
| codex-session-patcher | L3 | Maintained | Keep its CLI smoke and narrow dependency surface. |
| codex-voice-host | L3 | Constrained | Preserve protocol smoke; device/audio operation remains host-dependent. |
| codex-with-audio-and-zsh | L3 | Constrained | Keep component-link and entrypoint checks; audio remains host-dependent. |
| codex-zsh | L3 | Maintained | Keep exact zsh source and patch digest gates. |
| dae | L3 | Constrained | Preserve service test; live eBPF needs a suitable host kernel. |
| ghidra | L0 | Constrained | Retain only while official prebuilt distribution remains useful and auditable. |
| helium | L3 | Constrained | Require full source candidate review, patch compatibility, and no-substitutes verification. |
| hermes-agent | L3 | Maintained | Keep source lock determinism and offline functional smoke authoritative. |
| hermes-agent-audio | L3 | Constrained | Keep source-built provider checks; hardware/audio features need separate host validation. |
| hermes-agent-browser-backend-browser-use | L3 | Constrained | Keep the browser-use integration gate and external Chromium requirement explicit. |
| hermes-agent-browser-backend-camoufox | L3 | Constrained | Keep controller/browser compatibility and prebuilt browser exception reviewed. |
| hermes-agent-browser-backend-playwright | L3 | Constrained | Keep wheel-only Playwright boundary and browser integration checks visible. |
| hermes-agent-integrations | L3 | Maintained | Keep profile lock regeneration and representative optional-import smoke. |
| hermes-agent-interfaces | L3 | Maintained | Keep generated Python/Cargo lock and installed interface checks. |
| hermes-electron-desktop | L0 | Constrained | Retain nonguix Electron boundary; verify upstream/license fit before refreshing. |
| kilocode | L3 | Constrained | Review native npm payload inventory and exception delta on each lock update. |
| loro | L3 | Maintained | Keep offline Cargo closure and marimo dependent build. |
| marimo | L3 | Maintained | Keep standalone and service checks; optional stack remains separately scoped. |
| moldflow-insight-thinclient | L0 | Constrained | Requires user archive, Autodesk license, and an unsupported-by-vendor platform. |
| opencode-v1 | L3 | Constrained | Keep legacy-line status explicit; review native npm payloads and VM gate. |
| opencode-v2 | L3 | Constrained | Review native payload changes and current-line compatibility with the locked Bun. |
| overleaf-ctl | L3 | Constrained | Keep Docker/Podman and externally managed container data prerequisites clear. |
| overleaf-toolkit | L3 | Constrained | Keep upstream toolkit provenance clear; container images remain external. |
| pi | L3 | Maintained | Keep source/native build checks and explicit optional integrations. |
| pi-standalone | L3 | Constrained | Keep standalone smoke and Bun bootstrap exception visible. |
| python-ms-ivy | L3 | Maintained | Keep Z3-backed fixture; `ivyc` C++ backend remains out of scope. |
| qwenimage | L3 | Constrained | Review ncnn submodule pin and Vulkan/device prerequisites on updates. |
| rea | L3 | Maintained | Keep runtime closure smoke and VM service test; optional Frida remains omitted. |
| seafile | L3 | Maintained | Keep no-substitutes build, CLI smoke, and client-service VM test. |
| seafile-server | L3 | Constrained | Keep server-core scope explicit; Seahub/seafdav/FUSE are not included. |
| seaweedfs | L3 | Maintained | Keep variant and service VM matrix aligned with the supported feature set. |
| sing-box | L3 | Constrained | Preserve the `libcronet.so` exception and config/version smoke. |
| strata | L3 | Constrained | Keep no-substitutes build; GPU availability is a separate runtime prerequisite. |
| strata-cuda | L3 | Constrained | Keep non-free channel/toolkit and host-driver boundaries explicit. |
| vimium-c | L3 | Maintained | Keep the TypeScript build and packaged-file reference check. |

## Decisions

- Keep the current 39/6 manifest and exemption classification. There is no
  evidence-based case in this pass to remove an item or call one frozen.
- Keep Agent Cat at L2. Its current updater can refresh the source commit and
  source hash and then run the package gate. Raising it to L3 would require a
  deterministic updater for a manually curated Hackage dependency family,
  compatibility handling for the related crypton/TLS/WAI/Warp packages, and a
  reliable offline regression gate. The package is a small, specialized
  framework and no recurring update demand has justified that adapter cost.
  Reconsider after a second real update or clear use demand, rather than
  automating a one-off family now.
- Do not add CI in this pass. CI depends on the planned self-hosted Forge
  infrastructure; the local Make targets remain the current execution path.

## Onboarding check

The README shows the consumer sequence: add the authenticated channel, run
`guix pull`, install a concrete package by expression, and invoke its CLI.
On 2026-11-01 this path was exercised against the working tree in a disposable
`/tmp` Guix profile: `guix package -L "$PWD/modules" -e '(@ (under-sea
packages codex-session-patcher) codex-session-patcher)'` installed version
1.5.1, and the installed `codex-patcher --help` exited successfully. This
validates package resolution, build/install, and the entry point without
touching the user's normal profile. A sandboxed attempt could not access the
Guix daemon; rerunning locally resolved that environment boundary. A clean
`guix pull` against the remote authenticated channel was not part of this
check.
