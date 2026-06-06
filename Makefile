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
        prepare-version build bundle package release app cli fmt test \
        clean clean-dist run run-debug run-trace stop icons \
        build-app build-lua-runtime build-calendar-agent build-network-agent build-cli \
        copy-resources copy-debug-resources prepare-debug-app-bundle verify verify-release \
        stamp-plist stamp-calendar-agent-plist stamp-network-agent-plist sign notarize \
        print-arch print-run-arch print-version print-latest-tag print-package-sha256 \
        tag-patch tag-minor tag-major push-tags tag \
        run-build-app run-build-lua-runtime run-build-calendar-agent run-build-network-agent run-build-cli \
        demo \
        generate-docs generate-lua-docs check-docs serve-docs build-docs clean-docs \
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
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(APP_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(APP_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(APP_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(APP_PRODUCT)" \
		-output "$(APP_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(APP_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(APP_PRODUCT)" "$(APP_BIN)"
endif

build-lua-runtime: ## Internal target: build the Lua runtime executable for ARCH.
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(LUA_RUNTIME_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(LUA_RUNTIME_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(LUA_RUNTIME_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(LUA_RUNTIME_PRODUCT)" \
		-output "$(LUA_RUNTIME_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(LUA_RUNTIME_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(LUA_RUNTIME_PRODUCT)" "$(LUA_RUNTIME_BIN)"
endif

build-calendar-agent: ## Internal target: build the calendar agent executable for ARCH.
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(CALENDAR_AGENT_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(CALENDAR_AGENT_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(CALENDAR_AGENT_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(CALENDAR_AGENT_PRODUCT)" \
		-output "$(CALENDAR_AGENT_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(CALENDAR_AGENT_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(CALENDAR_AGENT_PRODUCT)" "$(CALENDAR_AGENT_BIN)"
endif

build-network-agent: ## Internal target: build the network agent executable for ARCH.
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(NETWORK_AGENT_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(NETWORK_AGENT_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(NETWORK_AGENT_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(NETWORK_AGENT_PRODUCT)" \
		-output "$(NETWORK_AGENT_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(NETWORK_AGENT_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(NETWORK_AGENT_PRODUCT)" "$(NETWORK_AGENT_BIN)"
endif

build-cli: ## Internal target: build the CLI executable for ARCH.
ifeq ($(ARCH),universal)
	@$(SWIFT_BUILD_RELEASE) --arch arm64 --product $(CLI_PRODUCT)
	@$(SWIFT_BUILD_RELEASE) --arch x86_64 --product $(CLI_PRODUCT)
	@lipo -create \
		".build/arm64-apple-macosx/release/$(CLI_PRODUCT)" \
		".build/x86_64-apple-macosx/release/$(CLI_PRODUCT)" \
		-output "$(CLI_BIN)"
else
	@$(SWIFT_BUILD_RELEASE) --arch $(ARCH) --product $(CLI_PRODUCT)
	@cp ".build/$(ARCH)-apple-macosx/release/$(CLI_PRODUCT)" "$(CLI_BIN)"
endif

copy-resources: ## Internal target: copy SwiftPM resource bundles and root assets into the app bundle.
	@mkdir -p "$(APP_BUNDLE)" "$(APP_RESOURCES)"
	@rm -rf "$(APP_RESOURCE_BUNDLE)" "$(APP_THEMES_DIR)"
ifeq ($(ARCH),universal)
	@test -d ".build/arm64-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" || { \
		echo "Missing resource bundle: .build/arm64-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)"; \
		find .build/arm64-apple-macosx/release -maxdepth 1 -name '*.bundle' -print; \
		exit 1; \
	}
	@cp -R ".build/arm64-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
else
	@test -d ".build/$(ARCH)-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" || { \
		echo "Missing resource bundle: .build/$(ARCH)-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)"; \
		find ".build/$(ARCH)-apple-macosx/release" -maxdepth 1 -name '*.bundle' -print; \
		exit 1; \
	}
	@cp -R ".build/$(ARCH)-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
endif
	@test -d "$(THEMES_DIR)" || { \
		echo "Missing themes directory: $(THEMES_DIR)"; \
		exit 1; \
	}
	@cp -R "$(THEMES_DIR)" "$(APP_THEMES_DIR)"
	@test -f "$(APP_THEMES_DIR)/default.toml" || { \
		echo "Missing bundled theme: $(APP_THEMES_DIR)/default.toml"; \
		exit 1; \
	}

copy-debug-resources: ## Internal target: copy debug SwiftPM resource bundles and root assets into the app bundle.
	@mkdir -p "$(APP_BUNDLE)" "$(APP_RESOURCES)"
	@rm -rf "$(APP_RESOURCE_BUNDLE)" "$(APP_THEMES_DIR)"
ifeq ($(RUN_ARCH),universal)
	@test -d ".build/arm64-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)" || { \
		echo "Missing resource bundle: .build/arm64-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)"; \
		find .build/arm64-apple-macosx/debug -maxdepth 1 -name '*.bundle' -print; \
		exit 1; \
	}
	@cp -R ".build/arm64-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
else
	@test -d ".build/$(RUN_ARCH)-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)" || { \
		echo "Missing resource bundle: .build/$(RUN_ARCH)-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)"; \
		find ".build/$(RUN_ARCH)-apple-macosx/debug" -maxdepth 1 -name '*.bundle' -print; \
		exit 1; \
	}
	@cp -R ".build/$(RUN_ARCH)-apple-macosx/debug/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
endif
	@test -d "$(THEMES_DIR)" || { \
		echo "Missing themes directory: $(THEMES_DIR)"; \
		exit 1; \
	}
	@cp -R "$(THEMES_DIR)" "$(APP_THEMES_DIR)"
	@test -f "$(APP_THEMES_DIR)/default.toml" || { \
		echo "Missing debug bundled theme: $(APP_THEMES_DIR)/default.toml"; \
		exit 1; \
	}

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
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier $(BUNDLE_ID)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable $(APP_EXEC)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string $(APP_ICON_FILE)' "$(PLIST)" >/dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile $(APP_ICON_FILE)' "$(PLIST)"

stamp-calendar-agent-plist: ## Internal target: stamp version into the calendar agent Info.plist.
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' "$(CALENDAR_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(VERSION)' "$(CALENDAR_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable $(CALENDAR_AGENT_EXEC)' "$(CALENDAR_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleName $(CALENDAR_AGENT_NAME)' "$(CALENDAR_AGENT_PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName $(CALENDAR_AGENT_NAME)' "$(CALENDAR_AGENT_PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string $(CALENDAR_AGENT_ICON_FILE)' "$(CALENDAR_AGENT_PLIST)" >/dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile $(CALENDAR_AGENT_ICON_FILE)' "$(CALENDAR_AGENT_PLIST)"

stamp-network-agent-plist: ## Internal target: stamp version into the network agent Info.plist.
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' "$(NETWORK_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(VERSION)' "$(NETWORK_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable $(NETWORK_AGENT_EXEC)' "$(NETWORK_AGENT_PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleName $(NETWORK_AGENT_NAME)' "$(NETWORK_AGENT_PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName $(NETWORK_AGENT_NAME)' "$(NETWORK_AGENT_PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string $(NETWORK_AGENT_ICON_FILE)' "$(NETWORK_AGENT_PLIST)" >/dev/null 2>&1 || \
		/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile $(NETWORK_AGENT_ICON_FILE)' "$(NETWORK_AGENT_PLIST)"

sign: ## Sign the app bundle, calendar agent, network agent, and CLI. Set CODESIGN_IDENTITY for Developer ID builds.
	@if [ "$(CODESIGN_IDENTITY)" = "-" ]; then \
		echo "Signing artifacts with ad-hoc identity"; \
		codesign --force --deep --sign - "$(APP_BUNDLE)"; \
		codesign --force --deep --sign - "$(CALENDAR_AGENT_BUNDLE)"; \
		codesign --force --deep --sign - "$(NETWORK_AGENT_BUNDLE)"; \
		codesign --force --sign - "$(CLI_BIN)"; \
	else \
		echo "Signing artifacts with $(CODESIGN_IDENTITY)"; \
		codesign --force --deep --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(APP_BUNDLE)"; \
		codesign --force --deep --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(CALENDAR_AGENT_BUNDLE)"; \
		codesign --force --deep --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(NETWORK_AGENT_BUNDLE)"; \
		codesign --force --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(CLI_BIN)"; \
	fi

notarize: ## Notarize the app bundle when NOTARY_SUBMIT=1 and a keychain profile is configured.
	@if [ "$(NOTARY_SUBMIT)" != "1" ]; then \
		echo "Skipping notarization (NOTARY_SUBMIT=$(NOTARY_SUBMIT))"; \
	elif [ "$(CODESIGN_IDENTITY)" = "-" ]; then \
		echo "Skipping notarization for ad-hoc signed build"; \
	elif [ -z "$(NOTARYTOOL_PROFILE)" ]; then \
		echo "NOTARYTOOL_PROFILE is required when NOTARY_SUBMIT=1"; \
		exit 1; \
	else \
		echo "Submitting $(APP_BUNDLE) for notarization"; \
		rm -f "$(NOTARY_ZIP)"; \
		ditto -c -k --keepParent "$(APP_BUNDLE)" "$(NOTARY_ZIP)"; \
		xcrun notarytool submit "$(NOTARY_ZIP)" --keychain-profile "$(NOTARYTOOL_PROFILE)" --wait; \
		xcrun stapler staple "$(APP_BUNDLE)"; \
	fi

verify: ## Show the built bundle structure and validate key packaged files.
	@echo "Built $(ARCH) artifacts:"
	@file "$(APP_BIN)"
	@file "$(LUA_RUNTIME_BIN)"
	@file "$(CALENDAR_AGENT_BIN)"
	@file "$(NETWORK_AGENT_BIN)"
	@file "$(CLI_BIN)"
	@test -f "$(PLIST)"
	@test -f "$(CALENDAR_AGENT_PLIST)"
	@test -f "$(NETWORK_AGENT_PLIST)"
	@test -d "$(APP_RESOURCE_BUNDLE)"
	@test -d "$(APP_THEMES_DIR)"
	@test -s "$(APP_ICON_ICNS)"
	@test -s "$(CALENDAR_AGENT_ICON_ICNS)"
	@test -s "$(NETWORK_AGENT_ICON_ICNS)"
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$(PLIST)")" = "$(APP_ICON_FILE)"
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$(CALENDAR_AGENT_PLIST)")" = "$(CALENDAR_AGENT_ICON_FILE)"
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$(NETWORK_AGENT_PLIST)")" = "$(NETWORK_AGENT_ICON_FILE)"
	@echo "Info.plist:"
	@plutil -p "$(PLIST)"
	@echo "Calendar agent Info.plist:"
	@plutil -p "$(CALENDAR_AGENT_PLIST)"
	@echo "Network agent Info.plist:"
	@plutil -p "$(NETWORK_AGENT_PLIST)"
	@echo "Packaged app root:"
	@ls -1 "$(APP_BUNDLE)"
	@echo "Packaged Contents:"
	@ls -1 "$(APP_CONTENTS)"
	@echo "Packaged Resources:"
	@ls -1 "$(APP_RESOURCES)" 2>/dev/null || true

verify-release: ## Validate the release package and print release fingerprints.
	@$(MAKE) --no-print-directory verify
	@test -f "$(PACKAGE_ZIP)"
	@test -f "$(APP_RESOURCE_BUNDLE)/easybar_api.lua"
	@test -f "$(APP_THEMES_DIR)/default.toml"
	@echo "Release package:"
	@ls -lh "$(PACKAGE_ZIP)"
	@echo "Build fingerprints:"
	@shasum -a 256 "$(APP_BIN)"
	@shasum -a 256 "$(PLIST)"
	@shasum -a 256 "$(APP_ICON_ICNS)"
	@shasum -a 256 "$(CALENDAR_AGENT_ICON_ICNS)"
	@shasum -a 256 "$(NETWORK_AGENT_ICON_ICNS)"
	@shasum -a 256 "$(APP_RESOURCE_BUNDLE)/easybar_api.lua"
	@shasum -a 256 "$(APP_THEMES_DIR)/default.toml"
	@shasum -a 256 "$(PACKAGE_ZIP)"
	@codesign -dv --verbose=4 "$(APP_BUNDLE)" 2>&1 || true

run: prepare-version ## Fast local run with debug builds and local agents.
	@mkdir -p "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory run-build-app RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-lua-runtime RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-calendar-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-network-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-cli RUN_ARCH=$(RUN_ARCH)
	@echo "Copying debug resources"
	@$(MAKE) --no-print-directory copy-debug-resources RUN_ARCH=$(RUN_ARCH)
	@echo "Preparing debug app bundle"
	@$(MAKE) --no-print-directory prepare-debug-app-bundle VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@echo "Starting local helper agents"
	@nohup env EASYBAR_LOG_LEVEL=info "$(CALENDAR_AGENT_BIN)" >/tmp/easybar-calendar-agent.dev.log 2>&1 &
	@nohup env EASYBAR_LOG_LEVEL=info "$(NETWORK_AGENT_BIN)" >/tmp/easybar-network-agent.dev.log 2>&1 &
	@echo "Launching $(APP_BIN) with EASYBAR_LOG_LEVEL=info"
	@echo "App logs follow stdout/stderr and configured logging.directory"
	@env EASYBAR_LOG_LEVEL=info "$(APP_BIN)"

run-debug: prepare-version ## Fast local run with debug builds and debug logging enabled.
	@mkdir -p "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory run-build-app RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-lua-runtime RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-calendar-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-network-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-cli RUN_ARCH=$(RUN_ARCH)
	@echo "Copying debug resources"
	@$(MAKE) --no-print-directory copy-debug-resources RUN_ARCH=$(RUN_ARCH)
	@echo "Preparing debug app bundle"
	@$(MAKE) --no-print-directory prepare-debug-app-bundle VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@echo "Starting local helper agents"
	@nohup env EASYBAR_LOG_LEVEL=debug "$(CALENDAR_AGENT_BIN)" >/tmp/easybar-calendar-agent.dev.log 2>&1 &
	@nohup env EASYBAR_LOG_LEVEL=debug "$(NETWORK_AGENT_BIN)" >/tmp/easybar-network-agent.dev.log 2>&1 &
	@echo "Launching $(APP_BIN) with EASYBAR_LOG_LEVEL=debug"
	@echo "App logs follow stdout/stderr and configured logging.directory"
	@env EASYBAR_LOG_LEVEL=debug "$(APP_BIN)"

run-trace: prepare-version ## Fast local run with debug builds and trace logging enabled.
	@mkdir -p "$(APP_MACOS)" "$(CALENDAR_AGENT_MACOS)" "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory run-build-app RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-lua-runtime RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-calendar-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-network-agent RUN_ARCH=$(RUN_ARCH)
	@$(MAKE) --no-print-directory run-build-cli RUN_ARCH=$(RUN_ARCH)
	@echo "Copying debug resources"
	@$(MAKE) --no-print-directory copy-debug-resources RUN_ARCH=$(RUN_ARCH)
	@echo "Preparing debug app bundle"
	@$(MAKE) --no-print-directory prepare-debug-app-bundle VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@echo "Starting local helper agents"
	@nohup env EASYBAR_LOG_LEVEL=trace "$(CALENDAR_AGENT_BIN)" >/tmp/easybar-calendar-agent.dev.log 2>&1 &
	@nohup env EASYBAR_LOG_LEVEL=trace "$(NETWORK_AGENT_BIN)" >/tmp/easybar-network-agent.dev.log 2>&1 &
	@echo "Launching $(APP_BIN) with EASYBAR_LOG_LEVEL=trace"
	@echo "App logs follow stdout/stderr and configured logging.directory"
	@env EASYBAR_LOG_LEVEL=trace "$(APP_BIN)"

run-build-app: ## Internal target: fast local app build for RUN_ARCH.
ifeq ($(RUN_ARCH),universal)
	@$(SWIFT_BUILD_DEBUG) --arch arm64 --product $(APP_PRODUCT)
	@$(SWIFT_BUILD_DEBUG) --arch x86_64 --product $(APP_PRODUCT)
	@mkdir -p "$(APP_MACOS)" "$(DIST_DIR)"
	@lipo -create \
		".build/arm64-apple-macosx/debug/$(APP_PRODUCT)" \
		".build/x86_64-apple-macosx/debug/$(APP_PRODUCT)" \
		-output "$(APP_BIN)"
else
	@$(SWIFT_BUILD_DEBUG) --arch $(RUN_ARCH) --product $(APP_PRODUCT)
	@mkdir -p "$(APP_MACOS)" "$(DIST_DIR)"
	@cp ".build/$(RUN_ARCH)-apple-macosx/debug/$(APP_PRODUCT)" "$(APP_BIN)"
endif

run-build-lua-runtime: ## Internal target: fast local Lua runtime build for RUN_ARCH.
ifeq ($(RUN_ARCH),universal)
	@$(SWIFT_BUILD_DEBUG) --arch arm64 --product $(LUA_RUNTIME_PRODUCT)
	@$(SWIFT_BUILD_DEBUG) --arch x86_64 --product $(LUA_RUNTIME_PRODUCT)
	@mkdir -p "$(APP_MACOS)" "$(DIST_DIR)"
	@lipo -create \
		".build/arm64-apple-macosx/debug/$(LUA_RUNTIME_PRODUCT)" \
		".build/x86_64-apple-macosx/debug/$(LUA_RUNTIME_PRODUCT)" \
		-output "$(LUA_RUNTIME_BIN)"
else
	@$(SWIFT_BUILD_DEBUG) --arch $(RUN_ARCH) --product $(LUA_RUNTIME_PRODUCT)
	@mkdir -p "$(APP_MACOS)" "$(DIST_DIR)"
	@cp ".build/$(RUN_ARCH)-apple-macosx/debug/$(LUA_RUNTIME_PRODUCT)" "$(LUA_RUNTIME_BIN)"
endif

run-build-calendar-agent: ## Internal target: fast local calendar agent build for RUN_ARCH.
ifeq ($(RUN_ARCH),universal)
	@$(SWIFT_BUILD_DEBUG) --arch arm64 --product $(CALENDAR_AGENT_PRODUCT)
	@$(SWIFT_BUILD_DEBUG) --arch x86_64 --product $(CALENDAR_AGENT_PRODUCT)
	@mkdir -p "$(CALENDAR_AGENT_MACOS)" "$(DIST_DIR)"
	@lipo -create \
		".build/arm64-apple-macosx/debug/$(CALENDAR_AGENT_PRODUCT)" \
		".build/x86_64-apple-macosx/debug/$(CALENDAR_AGENT_PRODUCT)" \
		-output "$(CALENDAR_AGENT_BIN)"
else
	@$(SWIFT_BUILD_DEBUG) --arch $(RUN_ARCH) --product $(CALENDAR_AGENT_PRODUCT)
	@mkdir -p "$(CALENDAR_AGENT_MACOS)" "$(DIST_DIR)"
	@cp ".build/$(RUN_ARCH)-apple-macosx/debug/$(CALENDAR_AGENT_PRODUCT)" "$(CALENDAR_AGENT_BIN)"
endif

run-build-network-agent: ## Internal target: fast local network agent build for RUN_ARCH.
ifeq ($(RUN_ARCH),universal)
	@$(SWIFT_BUILD_DEBUG) --arch arm64 --product $(NETWORK_AGENT_PRODUCT)
	@$(SWIFT_BUILD_DEBUG) --arch x86_64 --product $(NETWORK_AGENT_PRODUCT)
	@mkdir -p "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)"
	@lipo -create \
		".build/arm64-apple-macosx/debug/$(NETWORK_AGENT_PRODUCT)" \
		".build/x86_64-apple-macosx/debug/$(NETWORK_AGENT_PRODUCT)" \
		-output "$(NETWORK_AGENT_BIN)"
else
	@$(SWIFT_BUILD_DEBUG) --arch $(RUN_ARCH) --product $(NETWORK_AGENT_PRODUCT)
	@mkdir -p "$(NETWORK_AGENT_MACOS)" "$(DIST_DIR)"
	@cp ".build/$(RUN_ARCH)-apple-macosx/debug/$(NETWORK_AGENT_PRODUCT)" "$(NETWORK_AGENT_BIN)"
endif

run-build-cli: ## Internal target: fast local CLI build for RUN_ARCH.
ifeq ($(RUN_ARCH),universal)
	@$(SWIFT_BUILD_DEBUG) --arch arm64 --product $(CLI_PRODUCT)
	@$(SWIFT_BUILD_DEBUG) --arch x86_64 --product $(CLI_PRODUCT)
	@mkdir -p "$(DIST_DIR)"
	@lipo -create \
		".build/arm64-apple-macosx/debug/$(CLI_PRODUCT)" \
		".build/x86_64-apple-macosx/debug/$(CLI_PRODUCT)" \
		-output "$(CLI_BIN)"
else
	@$(SWIFT_BUILD_DEBUG) --arch $(RUN_ARCH) --product $(CLI_PRODUCT)
	@mkdir -p "$(DIST_DIR)"
	@cp ".build/$(RUN_ARCH)-apple-macosx/debug/$(CLI_PRODUCT)" "$(CLI_BIN)"
endif

stop: ## Stop EasyBar and its agents from brew services and local dist runs.
	@if command -v brew >/dev/null 2>&1; then \
		brew services stop gi8lino/tap/easybar >/dev/null 2>&1 || true; \
		brew services stop gi8lino/tap/easybar-calendar-agent >/dev/null 2>&1 || true; \
		brew services stop gi8lino/tap/easybar-network-agent >/dev/null 2>&1 || true; \
	fi
	@pkill -x "$(APP_EXEC)" >/dev/null 2>&1 || true
	@pkill -x "$(CALENDAR_AGENT_EXEC)" >/dev/null 2>&1 || true
	@pkill -x "$(NETWORK_AGENT_EXEC)" >/dev/null 2>&1 || true
	@pkill -f "$(APP_BUNDLE)/Contents/MacOS/$(APP_EXEC)" >/dev/null 2>&1 || true
	@pkill -f "$(CALENDAR_AGENT_BUNDLE)/Contents/MacOS/$(CALENDAR_AGENT_EXEC)" >/dev/null 2>&1 || true
	@pkill -f "$(NETWORK_AGENT_BUNDLE)/Contents/MacOS/$(NETWORK_AGENT_EXEC)" >/dev/null 2>&1 || true

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

generate-docs: ## Generate all checked-in docs from source stubs.
	@python3 scripts/generate/lua_reference_docs.py

generate-lua-docs: generate-docs ## Alias for generate-docs.

check-docs: generate-docs ## Verify generated docs are committed.
	@git diff --exit-code -- docs/content/lua/reference

serve-docs: $(DOCS_STAMP) generate-docs ## Generate and serve the docs locally.
	@$(DOCS_PYTHON) -m mkdocs serve -f $(DOCS_CONFIG)

build-docs: $(DOCS_STAMP) generate-docs ## Generate and build the docs locally.
	@$(DOCS_PYTHON) -m mkdocs build --strict -f $(DOCS_CONFIG)

clean-docs: ## Remove generated docs output and docs virtualenv.
	@rm -rf docs/.site $(DOCS_VENV) docs/content/lua/reference

##@ Icons

SVG := packaging/easybar-icon.svg
ICON_DIR := docs/assets/icons
ICON_SIZES := 16x16 32x32 48x48 64x64

favicon: ## Create favicons.
	@scripts/assets/favicons.sh "$(IMAGE_CONVERT)" "$(ICON_FONT)" "$(SVG)" "$(ICON_DIR)" $(ICON_SIZES)
