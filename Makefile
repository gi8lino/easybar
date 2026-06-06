APP_NAME := EasyBar
APP_TARGET := EasyBarApp
APP_EXEC := EasyBar
APP_PRODUCT := EasyBar
LUA_RUNTIME_PRODUCT := EasyBarLuaRuntime
LUA_RUNTIME_EXEC := EasyBarLuaRuntime
CALENDAR_AGENT_NAME := EasyBarCalendarAgent
CALENDAR_AGENT_PRODUCT := EasyBarCalendarAgent
CALENDAR_AGENT_EXEC := EasyBarCalendarAgent
NETWORK_AGENT_NAME := EasyBarNetworkAgent
NETWORK_AGENT_PRODUCT := EasyBarNetworkAgent
NETWORK_AGENT_EXEC := EasyBarNetworkAgent
CLI_PRODUCT := EasyBarCtl
CLI_EXEC := easybar
RESOURCE_BUNDLE_NAME := $(APP_NAME)_$(APP_TARGET).bundle

DIST_DIR := dist
THEMES_DIR := themes
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_RESOURCE_BUNDLE := $(APP_BUNDLE)/$(RESOURCE_BUNDLE_NAME)
APP_THEMES_DIR := $(APP_RESOURCES)/Themes
APP_BIN := $(APP_MACOS)/$(APP_EXEC)
LUA_RUNTIME_BIN := $(APP_MACOS)/$(LUA_RUNTIME_EXEC)

APP_ICON_SVG := packaging/easybar-icon.svg
APP_ICON_FILE := $(APP_NAME)
APP_ICON_ICNS := $(APP_RESOURCES)/$(APP_ICON_FILE).icns
ICON_FONT ?= /System/Library/Fonts/Supplemental/Arial.ttf

CALENDAR_AGENT_BUNDLE := $(DIST_DIR)/$(CALENDAR_AGENT_NAME).app
CALENDAR_AGENT_CONTENTS := $(CALENDAR_AGENT_BUNDLE)/Contents
CALENDAR_AGENT_MACOS := $(CALENDAR_AGENT_CONTENTS)/MacOS
CALENDAR_AGENT_RESOURCES := $(CALENDAR_AGENT_CONTENTS)/Resources
CALENDAR_AGENT_BIN := $(CALENDAR_AGENT_MACOS)/$(CALENDAR_AGENT_EXEC)
CALENDAR_AGENT_PLIST_TEMPLATE := Sources/EasyBarCalendarAgent/Info.plist
CALENDAR_AGENT_PLIST := $(CALENDAR_AGENT_CONTENTS)/Info.plist
CALENDAR_AGENT_ICON_SVG := packaging/easybar-calendar-agent-icon.svg
CALENDAR_AGENT_ICON_FILE := $(CALENDAR_AGENT_NAME)
CALENDAR_AGENT_ICON_ICNS := $(CALENDAR_AGENT_RESOURCES)/$(CALENDAR_AGENT_ICON_FILE).icns

NETWORK_AGENT_BUNDLE := $(DIST_DIR)/$(NETWORK_AGENT_NAME).app
NETWORK_AGENT_CONTENTS := $(NETWORK_AGENT_BUNDLE)/Contents
NETWORK_AGENT_MACOS := $(NETWORK_AGENT_CONTENTS)/MacOS
NETWORK_AGENT_RESOURCES := $(NETWORK_AGENT_CONTENTS)/Resources
NETWORK_AGENT_BIN := $(NETWORK_AGENT_MACOS)/$(NETWORK_AGENT_EXEC)
NETWORK_AGENT_PLIST_TEMPLATE := Sources/EasyBarNetworkAgent/Info.plist
NETWORK_AGENT_PLIST := $(NETWORK_AGENT_CONTENTS)/Info.plist
NETWORK_AGENT_ICON_SVG := packaging/easybar-network-agent-icon.svg
NETWORK_AGENT_ICON_FILE := $(NETWORK_AGENT_NAME)
NETWORK_AGENT_ICON_ICNS := $(NETWORK_AGENT_RESOURCES)/$(NETWORK_AGENT_ICON_FILE).icns

CLI_BIN := $(DIST_DIR)/$(CLI_EXEC)
PLIST_TEMPLATE := Sources/EasyBarApp/Info.plist
PLIST := $(APP_CONTENTS)/Info.plist

PACKAGE_NAME := $(APP_NAME)-$(VERSION).zip
PACKAGE_ZIP := $(DIST_DIR)/$(PACKAGE_NAME)
PACKAGE_STAGE := $(DIST_DIR)/package

BUILD_INFO := Sources/EasyBarShared/Build/BuildInfo.swift
LUA_API_STUB := Sources/EasyBarApp/Lua/easybar_api.lua

BUNDLE_ID ?= com.gi8lino.EasyBar
VERSION ?= dev
ARCH ?= universal
RUN_ARCH ?= arm64
CODESIGN_IDENTITY ?= -
NOTARYTOOL_PROFILE ?=
NOTARY_SUBMIT ?= 0
NOTARY_ZIP := $(DIST_DIR)/$(APP_NAME)-notarize.zip

VERSION_PREFIX ?= v
LATEST_TAG := $(shell git tag --list '$(VERSION_PREFIX)*' --sort=-v:refname | head -n 1)
CURRENT_VERSION := $(if $(LATEST_TAG),$(patsubst $(VERSION_PREFIX)%,%,$(LATEST_TAG)),0.0.0)

NEXT_PATCH := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m}.{n}.{p+1}")')
NEXT_MINOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m}.{n+1}.0")')
NEXT_MAJOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_VERSION)".split(".")); print(f"{m+1}.0.0")')

SWIFT_BUILD_RELEASE := swift build -c release
SWIFT_BUILD_DEBUG := swift build -c debug
LOCAL_HOME := $(CURDIR)/.home
LOCAL_CACHE_DIR := $(CURDIR)/.cache
LOCAL_CLANG_MODULE_CACHE := $(CURDIR)/.build/clang-module-cache
LOCAL_SWIFT_ENV := HOME="$(LOCAL_HOME)" XDG_CACHE_HOME="$(LOCAL_CACHE_DIR)" CLANG_MODULE_CACHE_PATH="$(LOCAL_CLANG_MODULE_CACHE)"
IMAGE_CONVERT ?= magick

ifeq ($(ARCH),universal)
ARCHES := arm64 x86_64
else ifeq ($(ARCH),arm64)
ARCHES := arm64
else ifeq ($(ARCH),x86_64)
ARCHES := x86_64
else
$(error Unsupported ARCH '$(ARCH)'. Use arm64, x86_64, or universal)
endif

ifeq ($(RUN_ARCH),universal)
RUN_ARCHES := arm64 x86_64
else ifeq ($(RUN_ARCH),arm64)
RUN_ARCHES := arm64
else ifeq ($(RUN_ARCH),x86_64)
RUN_ARCHES := x86_64
else
$(error Unsupported RUN_ARCH '$(RUN_ARCH)'. Use arm64, x86_64, or universal)
endif

.DEFAULT_GOAL := help

.PHONY: help all \
        generate check-generated generate-event-catalog generate-theme-tokens generate-swift-env \
        prepare-version build bundle package release app cli validate-config fmt test \
        clean clean-dist run run-debug run-trace stop icons \
        build-app build-lua-runtime build-calendar-agent build-network-agent build-cli \
        copy-resources copy-debug-resources prepare-debug-app-bundle verify verify-release \
        stamp-plist stamp-calendar-agent-plist stamp-network-agent-plist sign notarize \
        print-arch print-run-arch print-version print-latest-tag print-package-sha256 \
        tag-patch tag-minor tag-major push-tags tag \
        run-build-app run-build-lua-runtime run-build-calendar-agent run-build-network-agent run-build-cli \
        demo \
        generate-docs generate-lua-docs generate-config-docs check-docs serve-docs build-docs clean-docs \
        favicon

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Generated

generate: generate-theme-tokens generate-event-catalog generate-docs ## Generate all checked-in generated artifacts.

check-generated: generate ## Verify all checked-in generated artifacts are committed.
	@git diff --exit-code

generate-theme-tokens: ## Regenerate shared theme token artifacts for Swift and Lua.
	@python3 scripts/generate/theme_tokens.py

generate-event-catalog: ## Regenerate Lua event catalog files from the shared manifest.
	@python3 scripts/generate/event_catalog.py --version "$(VERSION)"

##@ Build

all: build ## Build the default artifacts.

prepare-version: ## Update generated build metadata and source-derived artifacts for VERSION.
	@$(MAKE) --no-print-directory generate-theme-tokens
	@$(MAKE) --no-print-directory generate-event-catalog
	@python3 scripts/build/stamp_build_info.py --file "$(BUILD_INFO)" --version "$(VERSION)"

generate-swift-env: ## Create repo-local directories for SwiftPM and compiler caches.
	@mkdir -p "$(LOCAL_HOME)/Library/org.swift.swiftpm/configuration" \
		"$(LOCAL_HOME)/Library/org.swift.swiftpm/security" \
		"$(LOCAL_HOME)/Library/Caches/org.swift.swiftpm" \
		"$(LOCAL_CACHE_DIR)" \
		"$(LOCAL_CLANG_MODULE_CACHE)"

build: bundle ## Build the app bundle and CLI for the selected ARCH.

app: prepare-version ## Build only the app executable for the selected ARCH.
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)

cli: prepare-version ## Build only the CLI executable for the selected ARCH.
	@$(MAKE) --no-print-directory build-cli ARCH=$(ARCH) VERSION=$(VERSION)

validate-config: cli ## Validate a config file with CONFIG=/path/to/config.toml.
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make validate-config CONFIG=/path/to/config.toml"; \
		exit 2; \
	fi
	@"$(CLI_BIN)" --validate-config --config "$(CONFIG)"

fmt: ## Format all Swift source files in the repository.
	@swift format format --in-place --recursive --parallel .

test: generate-theme-tokens generate-event-catalog generate-swift-env ## Run the Swift test suite.
	@env $(LOCAL_SWIFT_ENV) swift test --disable-sandbox

bundle: prepare-version clean-dist ## Build the .app bundle and CLI into dist/.
	@rm -rf "$(DIST_DIR)" ".build"
	@mkdir -p "$(APP_MACOS)" "$(APP_RESOURCES)" "$(CALENDAR_AGENT_MACOS)" "$(CALENDAR_AGENT_RESOURCES)" "$(NETWORK_AGENT_MACOS)" "$(NETWORK_AGENT_RESOURCES)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-lua-runtime ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-calendar-agent ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-network-agent ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-cli ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory copy-resources ARCH=$(ARCH)
	@$(MAKE) --no-print-directory icons
	@cp "$(PLIST_TEMPLATE)" "$(PLIST)"
	@cp "$(CALENDAR_AGENT_PLIST_TEMPLATE)" "$(CALENDAR_AGENT_PLIST)"
	@cp "$(NETWORK_AGENT_PLIST_TEMPLATE)" "$(NETWORK_AGENT_PLIST)"
	@$(MAKE) --no-print-directory stamp-plist VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@$(MAKE) --no-print-directory stamp-calendar-agent-plist VERSION=$(VERSION)
	@$(MAKE) --no-print-directory stamp-network-agent-plist VERSION=$(VERSION)
	@chmod +x "$(APP_BIN)" "$(LUA_RUNTIME_BIN)" "$(CALENDAR_AGENT_BIN)" "$(NETWORK_AGENT_BIN)" "$(CLI_BIN)"
	@$(MAKE) --no-print-directory sign CODESIGN_IDENTITY='$(CODESIGN_IDENTITY)'
	@$(MAKE) --no-print-directory notarize CODESIGN_IDENTITY='$(CODESIGN_IDENTITY)' NOTARYTOOL_PROFILE='$(NOTARYTOOL_PROFILE)' NOTARY_SUBMIT='$(NOTARY_SUBMIT)'
	@touch "$(APP_BUNDLE)" "$(CALENDAR_AGENT_BUNDLE)" "$(NETWORK_AGENT_BUNDLE)"
	@$(MAKE) --no-print-directory verify

package: bundle ## Create the release ZIP consumed by the Homebrew formula.
	@rm -rf "$(PACKAGE_STAGE)" "$(PACKAGE_ZIP)"
	@mkdir -p "$(PACKAGE_STAGE)"
	@cp -R "$(APP_BUNDLE)" "$(PACKAGE_STAGE)/EasyBar.app"
	@cp -R "$(CALENDAR_AGENT_BUNDLE)" "$(PACKAGE_STAGE)/EasyBarCalendarAgent.app"
	@cp -R "$(NETWORK_AGENT_BUNDLE)" "$(PACKAGE_STAGE)/EasyBarNetworkAgent.app"
	@cp "$(CLI_BIN)" "$(PACKAGE_STAGE)/easybar"
	@cd "$(PACKAGE_STAGE)" && zip -qry "../$(PACKAGE_NAME)" "EasyBar.app" "EasyBarCalendarAgent.app" "EasyBarNetworkAgent.app" "easybar"
	@rm -rf "$(PACKAGE_STAGE)"
	@echo "Created $(PACKAGE_ZIP)"

release: package ## Build and verify the zipped release artifact.
	@$(MAKE) --no-print-directory verify-release VERSION=$(VERSION) ARCH=$(ARCH)
	@echo "Release artifact ready: $(PACKAGE_ZIP)"

build-app: ## Internal target: build the app executable for ARCH.
	@scripts/build/build-product.sh release "$(ARCH)" "$(APP_PRODUCT)" "$(APP_BIN)"

build-lua-runtime: ## Internal target: build the Lua runtime executable for ARCH.
	@scripts/build/build-product.sh release "$(ARCH)" "$(LUA_RUNTIME_PRODUCT)" "$(LUA_RUNTIME_BIN)"

build-calendar-agent: ## Internal target: build the calendar agent executable for ARCH.
	@scripts/build/build-product.sh release "$(ARCH)" "$(CALENDAR_AGENT_PRODUCT)" "$(CALENDAR_AGENT_BIN)"

build-network-agent: ## Internal target: build the network agent executable for ARCH.
	@scripts/build/build-product.sh release "$(ARCH)" "$(NETWORK_AGENT_PRODUCT)" "$(NETWORK_AGENT_BIN)"

build-cli: ## Internal target: build the CLI executable for ARCH.
	@scripts/build/build-product.sh release "$(ARCH)" "$(CLI_PRODUCT)" "$(CLI_BIN)"

copy-resources: ## Internal target: copy SwiftPM resource bundles and root assets into the app bundle.
	@scripts/build/copy-resources.sh release "$(ARCH)" "$(RESOURCE_BUNDLE_NAME)" "$(APP_BUNDLE)" "$(APP_RESOURCE_BUNDLE)" "$(THEMES_DIR)" "$(APP_THEMES_DIR)"

copy-debug-resources: ## Internal target: copy debug SwiftPM resource bundles and root assets into the app bundle.
	@scripts/build/copy-resources.sh debug "$(RUN_ARCH)" "$(RESOURCE_BUNDLE_NAME)" "$(APP_BUNDLE)" "$(APP_RESOURCE_BUNDLE)" "$(THEMES_DIR)" "$(APP_THEMES_DIR)"

prepare-debug-app-bundle: ## Internal target: prepare local debug app bundle metadata.
	@mkdir -p "$(APP_CONTENTS)"
	@cp "$(PLIST_TEMPLATE)" "$(PLIST)"
	@$(MAKE) --no-print-directory stamp-plist VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@touch "$(APP_BUNDLE)"

icons: ## Generate .icns files from SVG icons using ImageMagick, sips, and iconutil.
	@scripts/assets/app_icons.sh "$(IMAGE_CONVERT)" "$(ICON_FONT)" "$(DIST_DIR)" \
		"$(APP_ICON_SVG):$(APP_ICON_ICNS)" \
		"$(CALENDAR_AGENT_ICON_SVG):$(CALENDAR_AGENT_ICON_ICNS)" \
		"$(NETWORK_AGENT_ICON_SVG):$(NETWORK_AGENT_ICON_ICNS)"

stamp-plist: ## Internal target: stamp version and bundle ID into Info.plist.
	@scripts/build/stamp-plist.sh \
		--plist "$(PLIST)" \
		--bundle-id "$(BUNDLE_ID)" \
		--version "$(VERSION)" \
		--executable "$(APP_EXEC)" \
		--name "$(APP_NAME)" \
		--icon-file "$(APP_ICON_FILE)"

stamp-calendar-agent-plist: ## Internal target: stamp version into the calendar agent Info.plist.
	@scripts/build/stamp-plist.sh \
		--plist "$(CALENDAR_AGENT_PLIST)" \
		--version "$(VERSION)" \
		--executable "$(CALENDAR_AGENT_EXEC)" \
		--name "$(CALENDAR_AGENT_NAME)" \
		--icon-file "$(CALENDAR_AGENT_ICON_FILE)"

stamp-network-agent-plist: ## Internal target: stamp version into the network agent Info.plist.
	@scripts/build/stamp-plist.sh \
		--plist "$(NETWORK_AGENT_PLIST)" \
		--version "$(VERSION)" \
		--executable "$(NETWORK_AGENT_EXEC)" \
		--name "$(NETWORK_AGENT_NAME)" \
		--icon-file "$(NETWORK_AGENT_ICON_FILE)"

sign: ## Sign the app bundle, calendar agent, network agent, and CLI. Set CODESIGN_IDENTITY for Developer ID builds.
	@scripts/release/sign-artifacts.sh \
		"$(CODESIGN_IDENTITY)" \
		"$(APP_BUNDLE)" \
		"$(CALENDAR_AGENT_BUNDLE)" \
		"$(NETWORK_AGENT_BUNDLE)" \
		"$(CLI_BIN)"

notarize: ## Notarize the app bundle when NOTARY_SUBMIT=1 and a keychain profile is configured.
	@scripts/release/notarize-app.sh \
		"$(NOTARY_SUBMIT)" \
		"$(CODESIGN_IDENTITY)" \
		"$(NOTARYTOOL_PROFILE)" \
		"$(APP_BUNDLE)" \
		"$(NOTARY_ZIP)"

verify: ## Show the built bundle structure and validate key packaged files.
	@scripts/build/verify-bundle.sh \
		"$(ARCH)" \
		"$(APP_BIN)" \
		"$(LUA_RUNTIME_BIN)" \
		"$(CALENDAR_AGENT_BIN)" \
		"$(NETWORK_AGENT_BIN)" \
		"$(CLI_BIN)" \
		"$(PLIST)" \
		"$(CALENDAR_AGENT_PLIST)" \
		"$(NETWORK_AGENT_PLIST)" \
		"$(APP_RESOURCE_BUNDLE)" \
		"$(APP_THEMES_DIR)" \
		"$(APP_ICON_ICNS)" \
		"$(CALENDAR_AGENT_ICON_ICNS)" \
		"$(NETWORK_AGENT_ICON_ICNS)" \
		"$(APP_ICON_FILE)" \
		"$(CALENDAR_AGENT_ICON_FILE)" \
		"$(NETWORK_AGENT_ICON_FILE)" \
		"$(APP_BUNDLE)" \
		"$(APP_CONTENTS)" \
		"$(APP_RESOURCES)"

verify-release: ## Validate the release package and print release fingerprints.
	@$(MAKE) --no-print-directory verify
	@scripts/release/verify-release.sh \
		"$(PACKAGE_ZIP)" \
		"$(APP_BIN)" \
		"$(PLIST)" \
		"$(APP_ICON_ICNS)" \
		"$(CALENDAR_AGENT_ICON_ICNS)" \
		"$(NETWORK_AGENT_ICON_ICNS)" \
		"$(APP_RESOURCE_BUNDLE)" \
		"$(APP_THEMES_DIR)" \
		"$(APP_BUNDLE)"

run: prepare-version ## Fast local run with debug builds and local agents.
	@scripts/dev/run-local.sh info "$(RUN_ARCH)" "$(VERSION)" "$(BUNDLE_ID)" "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)" "$(CALENDAR_AGENT_BIN)" "$(NETWORK_AGENT_BIN)" "$(APP_BIN)"

run-debug: prepare-version ## Fast local run with debug builds and debug logging enabled.
	@scripts/dev/run-local.sh debug "$(RUN_ARCH)" "$(VERSION)" "$(BUNDLE_ID)" "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)" "$(CALENDAR_AGENT_BIN)" "$(NETWORK_AGENT_BIN)" "$(APP_BIN)"

run-trace: prepare-version ## Fast local run with debug builds and trace logging enabled.
	@scripts/dev/run-local.sh trace "$(RUN_ARCH)" "$(VERSION)" "$(BUNDLE_ID)" "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)" "$(CALENDAR_AGENT_BIN)" "$(NETWORK_AGENT_BIN)" "$(APP_BIN)"

run-build-app: ## Internal target: fast local app build for RUN_ARCH.
	@scripts/build/build-product.sh debug "$(RUN_ARCH)" "$(APP_PRODUCT)" "$(APP_BIN)"

run-build-lua-runtime: ## Internal target: fast local Lua runtime build for RUN_ARCH.
	@scripts/build/build-product.sh debug "$(RUN_ARCH)" "$(LUA_RUNTIME_PRODUCT)" "$(LUA_RUNTIME_BIN)"

run-build-calendar-agent: ## Internal target: fast local calendar agent build for RUN_ARCH.
	@scripts/build/build-product.sh debug "$(RUN_ARCH)" "$(CALENDAR_AGENT_PRODUCT)" "$(CALENDAR_AGENT_BIN)"

run-build-network-agent: ## Internal target: fast local network agent build for RUN_ARCH.
	@scripts/build/build-product.sh debug "$(RUN_ARCH)" "$(NETWORK_AGENT_PRODUCT)" "$(NETWORK_AGENT_BIN)"

run-build-cli: ## Internal target: fast local CLI build for RUN_ARCH.
	@scripts/build/build-product.sh debug "$(RUN_ARCH)" "$(CLI_PRODUCT)" "$(CLI_BIN)"

stop: ## Stop EasyBar and its agents from brew services and local dist runs.
	@scripts/dev/stop-local.sh \
		"$(APP_EXEC)" \
		"$(CALENDAR_AGENT_EXEC)" \
		"$(NETWORK_AGENT_EXEC)" \
		"$(APP_BUNDLE)" \
		"$(CALENDAR_AGENT_BUNDLE)" \
		"$(NETWORK_AGENT_BUNDLE)"

##@ Cleanup

clean-dist: ## Remove dist/.
	@rm -rf "$(DIST_DIR)"

clean: ## Remove dist/, .build, and reset BuildInfo.swift and generated event catalog to dev.
	@rm -rf "$(DIST_DIR)" ".build"
	@python3 scripts/build/stamp_build_info.py --file "$(BUILD_INFO)" --version dev
	@python3 scripts/generate/event_catalog.py --version dev

##@ Info

print-arch: ## Print the selected ARCH.
	@echo "$(ARCH)"

print-run-arch: ## Print the selected RUN_ARCH.
	@echo "$(RUN_ARCH)"

print-version: ## Print the current version derived from the latest tag.
	@echo "$(CURRENT_VERSION)"

print-latest-tag: ## Print the latest matching git tag.
	@echo "$(LATEST_TAG)"

print-package-sha256: package ## Print the SHA-256 of the packaged zip.
	@shasum -a 256 "$(PACKAGE_ZIP)"

##@ Tagging

tag-patch: ## Create the next patch tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_PATCH)" -m "Release $(VERSION_PREFIX)$(NEXT_PATCH)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_PATCH)"

tag-minor: ## Create the next minor tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MINOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MINOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MINOR)"

tag-major: ## Create the next major tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MAJOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MAJOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MAJOR)"

push-tags: ## Push commits and tags to origin.
	@git push --follow-tags

tag: ## Show latest tag.
	@echo "Latest version: $(LATEST_TAG)"

##@ Tools

demo: ## Populate the demo calendar with random events.
	@swift scripts/tools/populate-demo-calendar.swift demo

##@ Docs

DOCS_DIR := docs
DOCS_CONFIG := $(DOCS_DIR)/mkdocs.yml
DOCS_REQUIREMENTS := $(DOCS_DIR)/requirements.txt
DOCS_VENV := $(DOCS_DIR)/.venv
DOCS_PYTHON := $(DOCS_VENV)/bin/python
DOCS_STAMP := $(DOCS_VENV)/.requirements-installed

$(DOCS_PYTHON):
	@python3 -m venv $(DOCS_VENV)

$(DOCS_STAMP): $(DOCS_REQUIREMENTS) | $(DOCS_PYTHON)
	@$(DOCS_PYTHON) -m pip install --upgrade pip
	@$(DOCS_PYTHON) -m pip install -r $(DOCS_REQUIREMENTS)
	@touch $(DOCS_STAMP)

generate-docs: generate-lua-docs generate-config-docs ## Generate all checked-in docs from source stubs.

generate-lua-docs: ## Generate Lua reference docs from source stubs.
	@python3 scripts/generate/lua_reference_docs.py

generate-config-docs: ## Generate the config reference from config.defaults.toml.
	@python3 scripts/generate/config_reference_docs.py

check-docs: generate-docs ## Verify generated docs are committed.
	@git diff --exit-code -- docs/content/lua/reference docs/content/configuration/reference.md

serve-docs: $(DOCS_STAMP) generate-docs ## Generate and serve the docs locally.
	@$(DOCS_PYTHON) -m mkdocs serve -f $(DOCS_CONFIG)

build-docs: $(DOCS_STAMP) generate-docs ## Generate and build the docs locally.
	@$(DOCS_PYTHON) -m mkdocs build --strict -f $(DOCS_CONFIG)

clean-docs: ## Remove generated docs output and docs virtualenv.
	@rm -rf docs/.site $(DOCS_VENV) docs/content/lua/reference docs/content/configuration/reference.md

##@ Icons

SVG := packaging/easybar-icon.svg
ICON_DIR := docs/assets/icons
ICON_SIZES := 16x16 32x32 48x48 64x64

favicon: ## Create favicons.
	@scripts/assets/favicons.sh "$(IMAGE_CONVERT)" "$(ICON_FONT)" "$(SVG)" "$(ICON_DIR)" $(ICON_SIZES)


