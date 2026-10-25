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

TM          := $(GUIX) time-machine -C $(CHANNELS) --
BUILD_FLAGS := --cores=$(CORES) --max-silent-time=$(MAX_SILENT) --keep-failed


.DEFAULT_GOAL := help

.PHONY: help
help: ## list targets
	@echo "under-sea targets:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sed -E 's/:.*## /  /'
	@echo
	@echo "variables: EXPR, HOST, MANIFEST (default manifest.scm), CORES (default 1), MAX_SILENT, CHANNELS, COPY_FLAGS"

# ---------------------------------------------------------------- verification
.PHONY: verify-all verify verify-packaging verify-phase7 verify-system verify-credentials
.PHONY: lint locks exceptions elf hygiene
verify-all: ## run every verification gate
	scripts/verify-all.sh

verify: verify-all ## alias for verify-all

verify-packaging: ## packaging quality (lint, locks, exceptions, ELF)
	scripts/verify-packaging.sh

verify-phase7: ## per-package smoke (Xvfb browser/desktop, runtime imports)
	scripts/verify-phase7.sh

verify-system: ## service/system layer (container smoke + VM marionette tests)
	scripts/verify-system.sh

verify-credentials: ## environment-gated credential/network checks
	scripts/verify-credentials.sh

lint: ## guix lint over all (under-sea packages ...)
	scripts/verify-lint.sh

locks: ## every *-lock.scm origin is a fixed-output sha256
	scripts/verify-locks.sh

hygiene: ## unused imports and unreferenced private definitions
	scripts/verify-hygiene.sh

refresh: ## check upstream versions (guix refresh updaters)
	scripts/refresh.sh $(ARGS)

exceptions: ## check planning/precompiled-exceptions.json
	scripts/verify-exceptions.sh

elf: ## scan built outputs for executable-stack objects
	VERIFY_PACKAGING_ELF=1 scripts/verify-packaging.sh

# ----------------------------------------------------------------- build & friends
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
.PHONY: sing-box dae hermes-agent hermes-agent-interfaces hermes-agent-integrations
.PHONY: hermes-agent-audio agent-browser hermes-electron-desktop
.PHONY: codex pi pi-standalone kilocode ghidra strata strata-cuda agent-cat
.PHONY: moldflow adsk-licensing codex-session-patcher
.PHONY: seafile rea seaweedfs seaweedfs-rocksdb seaweedfs-full marimo marimo-extras opencode-v1 opencode-v2
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

codex-session-patcher: ## build codex-session-patcher
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages codex-session-patcher) codex-session-patcher)'

agent-cat: ## build agent-cat (Haskell agentic workflows framework)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages agent-cat) agent-cat)'

seafile: ## build the Seafile sync client daemon and CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages seafile) seafile)'

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

opencode-v1: ## build the legacy OpenCode 1 CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages opencode-v1) opencode-v1)'

opencode-v2: ## build the current OpenCode 2 CLI
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages opencode-v2) opencode-v2)'

ivy: ## build IVy protocol verification tool (python-ms-ivy)
	$(TM) build -L $(CURDIR)/modules $(BUILD_FLAGS) -e '(@ (under-sea packages ivy) python-ms-ivy)'

# ---------------------------------------------------------------- maintenance
.PHONY: clean clean-dry
clean: ## drop stale /tmp/guix-build-* trees
	scripts/clean-build-artifacts.sh

clean-dry: ## preview what `make clean` would remove
	scripts/clean-build-artifacts.sh --dry-run
