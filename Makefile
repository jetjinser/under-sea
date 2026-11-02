# under-sea - a small wrapper for the pinned-channel workflow.
#
# Everything goes through the channels pinned in channels.scm; the
# (under-sea ...) modules are resolved with -L $(CURDIR)/modules
#
#   make                                        list targets
#   make verify-all                             run every verification gate
#   make build  EXPR='(@ (under-sea packages hermes) hermes-agent)'
#   make shell  EXPR='(@ (under-sea packages strata) strata)'
#   make copy   HOST=user@host:2222 EXPR='(@ (under-sea packages strata) strata)'
#   make clean                                  drop stale /tmp/guix-build-* trees

GUIX       ?= guix
CHANNELS   ?= channels.scm
MANIFEST   ?= manifest.scm
CORES      ?= 1
MAX_SILENT ?= 7200
HOST       ?=
EXPR       ?=
COPY_FLAGS ?=
UPDATE_WORKDIR ?= /var/tmp/under-sea-update
APPLY      ?= 0
VERIFY     ?= 0

TM          := $(GUIX) time-machine -C $(CHANNELS) --
BUILD_FLAGS := --cores=$(CORES) --max-silent-time=$(MAX_SILENT) --keep-failed


.DEFAULT_GOAL := help

# help-group: Start here
.PHONY: help
help: ## list targets
	@echo "under-sea targets:"
	@awk -f scripts/make-help.awk $(firstword $(MAKEFILE_LIST))
	@echo
	@echo "Common: make update PACKAGE=name APPLY=1 | make verify-ci | make build EXPR='(@ (under-sea packages M) P)'"
	@echo "Variables: PACKAGE, VERSION, CANDIDATE, OUTPUT, EXPR, HOST, MANIFEST, CORES, MAX_SILENT, CHANNELS, UPDATE_WORKDIR, APPLY=1, VERIFY=1 (prepare only), SKIP_VERIFY=1 (one-command update), COMMIT=1, VM=1, ALL=1, DETERMINISM=1"

# ---------------------------------------------------------------- verification
.PHONY: verify-all verify verify-ci verify-ci-update verify-ci-standalone verify-ci-packaging verify-ci-phase7 verify-ci-system verify-standalone verify-packaging verify-phase7 verify-system verify-browser verify-credentials
.PHONY: verify-overleaf verify-camoufox verify-browser-use verify-helium
.PHONY: lint locks exceptions elf hygiene
# help-group: Verification
verify-all: ## run every verification gate
	scripts/verify-all.sh

verify: verify-all ## alias for verify-all

# help-group: One-command package update
.PHONY: update update-dependencies update-audit update-validate update-prepare update-bun update-helium update-helium-candidate update-helium-hashes update-helium-review update-verify update-vm update-report update-publish-dry-run update-detect update-detect-helium update-detect-qwenimage update-test update-clean
update: ## update one package locally (PACKAGE=name APPLY=1 VERIFY=1 COMMIT=1)
	guix shell guile guile-json python-minimal -- guile --no-auto-compile -L scripts/update -s scripts/update/update.scm $(if $(PACKAGE),--package "$(PACKAGE)",) $(if $(filter 1,$(ALL)),--all,) $(if $(filter 1,$(APPLY)),--apply,) $(if $(filter 1,$(COMMIT)),--commit,) $(if $(filter 1,$(VM)),--vm,) $(if $(filter 1,$(FORCE)),--force,) $(if $(filter 1,$(DETERMINISM)),--determinism,) $(if $(filter 1,$(SKIP_VERIFY)),--skip-verify,)

# help-group: Update inventory and discovery
update-dependencies: ## validate the update dependency graph
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/dependencies.scm

update-audit: ## ensure every user-facing package is classified
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/audit.scm

update-validate: ## validate planning/update-manifest.json
	guix shell python-minimal -- python3 scripts/update/run.py validate --manifest planning/update-manifest.json

# help-group: Prepare and verify updates
update-prepare: ## prepare a pin update (PACKAGE=name [VERSION=x])
	@test -n "$(PACKAGE)" || { echo "PACKAGE is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/run.py prepare --package "$(PACKAGE)" $(if $(VERSION),--version "$(VERSION)",) --workdir "$(UPDATE_WORKDIR)/$(PACKAGE)$(if $(VERSION),-$(VERSION),)" $(if $(filter 1,$(APPLY)),--apply,) $(if $(filter 1,$(VERIFY)),--verify,)

update-bun: ## prepare a Bun package (PACKAGE=name [VERSION=x])
	@test -n "$(PACKAGE)" || { echo "PACKAGE is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/bun.py --package "$(PACKAGE)" $(if $(VERSION),--version "$(VERSION)",) --workdir "$(UPDATE_WORKDIR)/$(PACKAGE)$(if $(VERSION),-$(VERSION),)" $(if $(filter 1,$(APPLY)),--apply,) $(if $(filter 1,$(VERIFY)),--verify,)

update-verify: ## build a package and its manifest dependents (PACKAGE=name)
	@test -n "$(PACKAGE)" || { echo "PACKAGE is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/verify.py --package "$(PACKAGE)"

update-vm: ## run the VM test for a package (PACKAGE=name)
	@test -n "$(PACKAGE)" || { echo "PACKAGE is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/vm.py --package "$(PACKAGE)"

update-publish-dry-run: ## print the publish plan (PACKAGE=name VERSION=x)
	@test -n "$(PACKAGE)" -a -n "$(VERSION)" || { echo "PACKAGE and VERSION are required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/publish.py --package "$(PACKAGE)" --version "$(VERSION)"

# help-group: Update inventory and discovery
update-report: ## summarize update coverage and autonomy levels
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/report.scm

update-detect: ## report upstream versions from planning/update-manifest.json
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/detect.scm --all --json

update-detect-helium: ## report Helium's nine pinned source components
	guix shell python-minimal -- python3 scripts/update/helium.py --json $(if $(filter 1,$(NO_NETWORK)),--no-network,)

# help-group: Specialized update transactions
update-helium: ## dry-run or atomically apply a complete Helium candidate transaction
	@test -n "$(CANDIDATE)" || { echo "CANDIDATE is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/helium.py --no-network --json --candidate "$(CANDIDATE)" $(if $(filter 1,$(APPLY)),--apply,) $(if $(filter 1,$(ACCEPT_CHROMIUM_CHANGE)),--accept-chromium-change,)

update-helium-candidate: ## discover upstream Helium tags and write a reviewable candidate (OUTPUT=path)
	@test -n "$(OUTPUT)" || { echo "OUTPUT is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/helium.py --json --discover-candidate "$(OUTPUT)"

update-helium-hashes: ## resolve candidate origin hashes from its pinned versions/revisions
	@test -n "$(CANDIDATE)" || { echo "CANDIDATE is required" >&2; exit 2; }
	@test -n "$(OUTPUT)" || { echo "OUTPUT is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/helium.py --no-network --json --resolve-candidate "$(CANDIDATE)" --output-candidate "$(OUTPUT)" $(if $(WORKDIR),--workdir "$(WORKDIR)",)

update-helium-review: ## write a source/hash diff report for human review
	@test -n "$(CANDIDATE)" || { echo "CANDIDATE is required" >&2; exit 2; }
	@test -n "$(OUTPUT)" || { echo "OUTPUT is required" >&2; exit 2; }
	guix shell python-minimal -- python3 scripts/update/helium.py --no-network --review-candidate "$(CANDIDATE)" --review-output "$(OUTPUT)"

# help-group: Update inventory and discovery
update-detect-qwenimage: ## check the qwenimage ncnn submodule gate
	guix shell python-minimal -- python3 scripts/update/qwenimage.py --json

# help-group: Update tooling and cleanup
update-test: ## unit-test the update framework
	guix shell python-minimal -- python3 -m unittest discover -s scripts/update -p 'test_*.py'
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/test-scheme.scm

update-clean: ## remove the managed update workdir
	@test -n "$(UPDATE_WORKDIR)" || { echo "UPDATE_WORKDIR is empty" >&2; exit 2; }
	@case "$(UPDATE_WORKDIR)" in /var/tmp/*|/tmp/*) rm -rf -- "$(UPDATE_WORKDIR)" ;; *) echo "refusing to remove $(UPDATE_WORKDIR)" >&2; exit 2 ;; esac

# help-group: Verification
verify-standalone: ## focused standalone-package matrix
	scripts/verify-standalone.sh

verify-ci: ## CI suite: update framework, package builds and smoke checks
	$(MAKE) verify-ci-update
	$(MAKE) verify-ci-standalone
	$(MAKE) verify-ci-packaging
	$(MAKE) verify-ci-phase7
	$(MAKE) verify-ci-system

verify-ci-update: ## CI: update inventory audit and framework tests
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/audit.scm
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/dependencies.scm
	guix shell python-minimal -- python3 -m unittest discover -s scripts/update -p 'test_*.py'
	guix shell guile guile-json -- guile --no-auto-compile -L scripts/update -s scripts/update/test-scheme.scm

verify-ci-standalone: ## CI: build/resolve standalone packages and smoke-test them
	scripts/verify-standalone.sh

verify-ci-packaging: ## CI: lint packages and verify locks/exceptions
	scripts/verify-packaging.sh

verify-ci-phase7: ## CI: smoke-test package matrix (large suites skipped)
	VERIFY_PHASE7_SKIP_HERMES=1 VERIFY_PHASE7_SKIP_AGENT_BROWSER=1 \
	  scripts/verify-phase7.sh

verify-ci-system: ## CI: run service-container checks (VM suite skipped)
	VERIFY_SYSTEM_SKIP_VM=1 scripts/verify-system.sh

verify-packaging: ## packaging quality (lint, locks, exceptions, ELF)
	scripts/verify-packaging.sh

verify-phase7: ## per-package smoke (Xvfb browser/desktop, runtime imports)
	scripts/verify-phase7.sh

verify-overleaf: ## smoke Overleaf CLI init against packaged templates
	scripts/verify-overleaf.sh

verify-system: ## service/system layer (container smoke + VM marionette tests)
	scripts/verify-system.sh

verify-browser: ## browser VM integration (Playwright + Chromium navigation)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea tests browser) %test-under-sea-browser)'

verify-camoufox: ## Camoufox controller, paired-browser and backend VM smoke
	scripts/verify-hermes-camoufox.sh

verify-helium: ## pinned no-substitutes Helium build and CLI smoke
	scripts/verify-helium.sh

verify-browser-use: ## browser-use CDP + Chromium VM smoke
	scripts/verify-hermes-browser-use.sh

verify-credentials: ## environment-gated credential/network checks
	scripts/verify-credentials.sh

lint: ## guix lint over all (under-sea packages ...)
	scripts/verify-lint.sh

locks: ## every *-lock.scm origin is a fixed-output sha256
	scripts/verify-locks.sh

hygiene: ## unused imports and unreferenced private definitions
	scripts/verify-hygiene.sh

# help-group: Upstream maintenance
refresh: ## check upstream versions (guix refresh updaters)
	scripts/refresh.sh $(ARGS)

# help-group: Verification
exceptions: ## check planning/precompiled-exceptions.json
	scripts/verify-exceptions.sh

elf: ## scan built outputs for executable-stack objects
	VERIFY_PACKAGING_ELF=1 scripts/verify-packaging.sh

# ----------------------------------------------------------------- build & friends
# help-group: Build and environment
.PHONY: build env shell install copy
build: ## build a package: make build EXPR='(@ (under-sea packages M) P)'
	@test -n "$(EXPR)" || { echo "usage: make build EXPR='(@ (under-sea packages M) P)'"; exit 2; }
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '$(EXPR)'

env: ## open the development shell (guix shell -m manifest.scm)
	$(GUIX) shell -m $(MANIFEST)

shell: ## open a shell for a package: make shell EXPR='...'
	@test -n "$(EXPR)" || { echo "usage: make shell EXPR='(@ (under-sea packages M) P)'"; exit 2; }
	$(TM) shell -L $(CURDIR)/modules -e '$(EXPR)'

install: ## install a package into the current profile: make install EXPR='...'
	@test -n "$(EXPR)" || { echo "usage: make install EXPR='(@ (under-sea packages M) P)'"; exit 2; }
	$(TM) install -L $(CURDIR)/modules -e '$(EXPR)'

copy: ## copy a package's closure to a host: make copy HOST=user@host:2222 EXPR='...'
	@test -n "$(HOST)" || { echo "usage: make copy HOST=user@host[:port] EXPR='(@ (under-sea packages M) P)'"; exit 2; }
	@test -n "$(EXPR)" || { echo "usage: make copy HOST=user@host[:port] EXPR='(@ (under-sea packages M) P)'"; exit 2; }
	@items="$$($(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '$(EXPR)')" || exit 1; \
	  test -n "$$items" || { echo "make copy: the build produced no output (check EXPR)"; exit 1; }; \
	  $(GUIX) copy $(COPY_FLAGS) --to=$(HOST) $$items

# ---------------------------------------------------------------- per-component
# help-group: Package builds
.PHONY: sing-box dae hermes-agent hermes-agent-interfaces hermes-agent-integrations hermes-browser-backend-playwright hermes-agent-camoufox hermes-browser-backend-camoufox hermes-agent-browser-use hermes-browser-backend-browser-use
.PHONY: hermes-agent-audio agent-browser hermes-electron-desktop
.PHONY: codex pi pi-standalone kilocode ghidra strata strata-cuda agent-cat
.PHONY: moldflow adsk-licensing codex-session-patcher
.PHONY: seafile seafile-server rea seaweedfs seaweedfs-rocksdb seaweedfs-full marimo marimo-extras loro opencode-v1 opencode-v2
sing-box: ## build sing-box
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages sing-box) sing-box)'

dae: ## build dae
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages dae) dae)'

hermes-agent: ## build the Hermes core runtime
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes) hermes-agent)'

hermes-agent-interfaces: ## build the Hermes interface runtime
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes) hermes-agent-interfaces)'

hermes-agent-integrations: ## build the Hermes integration runtime
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes) hermes-agent-integrations)'

hermes-browser-backend-playwright: ## build the Hermes Playwright/Chromium backend
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-browser-backends) hermes-browser-backend-playwright)'

hermes-agent-camoufox: ## build the Hermes Camoufox controller
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-camoufox) hermes-agent-camoufox)'

hermes-browser-backend-camoufox: ## build the Hermes Camoufox browser backend
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-camoufox) hermes-browser-backend-camoufox)'

hermes-agent-browser-use: ## build the Hermes browser-use runtime
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-browser-use) hermes-agent-browser-use)'

hermes-browser-backend-browser-use: ## build the Hermes browser-use backend
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-browser-use) hermes-browser-backend-browser-use)'

hermes-agent-audio: ## build the Hermes audio runtime
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-audio) hermes-agent-audio)'

agent-browser: ## build the agent-browser CLI (embedded dashboard)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages agent-browser) agent-browser)'

hermes-electron-desktop: ## build the Hermes Electron desktop shell
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages hermes-electron) hermes-electron-desktop)'

codex: ## build Codex (CLI + V8 host + voice + zsh + SDK)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages codex) codex)'

pi: ## build the Pi CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages pi) pi)'

pi-standalone: ## build the Pi standalone binary
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages pi) pi-standalone)'

kilocode: ## build the kilocode TUI (kilo)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages kilocode) kilocode)'

ghidra: ## build Ghidra
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages ghidra) ghidra)'

strata: ## build Strata (AMD/HIP)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages strata) strata)'

strata-cuda: ## build Strata (NVIDIA/CUDA, needs the non-free channels)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages strata) strata-cuda)'

moldflow: ## build the Moldflow thin-client (needs MOLDFLOW_ARCHIVE)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages moldflow) moldflow-insight-thinclient)'

adsk-licensing: ## build the Autodesk Licensing Service (needs MOLDFLOW_ARCHIVE)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages adsk-licensing) adsk-licensing)'

qwenimage: ## build qwenimage-ncnn-vulkan
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages qwenimage-ncnn-vulkan) qwenimage-ncnn-vulkan)'

codex-session-patcher: ## build codex-session-patcher
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages codex-session-patcher) codex-session-patcher)'

agent-cat: ## build agent-cat (Haskell agentic workflows framework)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages agent-cat) agent-cat)'

camofox-browser: ## build the camofox-browser REST server
	$(TM) build -L $(CURDIR)/modules --no-substitutes -e '(@ (under-sea packages camofox-browser) camofox-browser-for-hermes)'

overleaf-toolkit: ## build the Overleaf deployment toolkit
	$(TM) build -L $(CURDIR)/modules --no-substitutes -e '(@ (under-sea packages overleaf) overleaf-toolkit)'

overleaf-ctl: ## build the Overleaf control script
	$(TM) build -L $(CURDIR)/modules --no-substitutes -e '(@ (under-sea packages overleaf) overleaf-ctl)'

seafile: ## build the Seafile sync client daemon and CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seafile) seafile)'

seafile-server: ## build the Seafile server core
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seafile-server) seafile-server)'

rea: ## build the REA reverse-engineering CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages rea) rea)'

seaweedfs: ## build the SeaweedFS weed server
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seaweedfs) seaweedfs)'

seaweedfs-rocksdb: ## build SeaweedFS with the RocksDB filer backend
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seaweedfs) seaweedfs-rocksdb)'

seaweedfs-full: ## build SeaweedFS with RocksDB, SQLite, TiKV, YDB and Tarantool
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seaweedfs) seaweedfs-full)'

marimo: ## build the marimo notebook server and CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages marimo) marimo)'

marimo-extras: ## build marimo with the SQL and MCP extras
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages marimo) marimo-with-extras)'

loro: ## build the Loro Python CRDT bindings
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages loro) loro)'

opencode-v1: ## build the legacy OpenCode 1 CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages opencode-v1) opencode-v1)'

opencode-v2: ## build the current OpenCode 2 CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages opencode-v2) opencode-v2)'

ivy: ## build IVy protocol verification tool (python-ms-ivy)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages ivy) python-ms-ivy)'

# ---------------------------------------------------------------- maintenance
# help-group: Maintenance
.PHONY: clean clean-dry
clean: ## drop stale /tmp/guix-build-* trees
	scripts/clean-build-artifacts.sh

clean-dry: ## preview what `make clean` would remove
	scripts/clean-build-artifacts.sh --dry-run
