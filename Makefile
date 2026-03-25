APP_NAME := EasyBar
APP_EXEC := EasyBar
APP_PRODUCT := EasyBar
CALENDAR_AGENT_PRODUCT := EasyBarCalendarAgent
NETWORK_AGENT_PRODUCT := EasyBarNetworkAgent
CLI_PRODUCT := easybarctl
RESOURCE_BUNDLE_NAME := $(APP_NAME)_$(APP_PRODUCT).bundle

DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_BIN := $(APP_MACOS)/$(APP_EXEC)
CALENDAR_AGENT_BIN := $(DIST_DIR)/$(CALENDAR_AGENT_PRODUCT)
NETWORK_AGENT_BIN := $(DIST_DIR)/$(NETWORK_AGENT_PRODUCT)
CLI_BIN := $(DIST_DIR)/$(CLI_PRODUCT)
PLIST_TEMPLATE := packaging/Info.plist
PLIST := $(APP_CONTENTS)/Info.plist

# SwiftPM places the copied resource bundle at the app bundle root in this setup.
APP_RESOURCE_BUNDLE := $(APP_BUNDLE)/$(RESOURCE_BUNDLE_NAME)

PACKAGE_NAME := $(APP_NAME)-$(VERSION).zip
PACKAGE_ZIP := $(DIST_DIR)/$(PACKAGE_NAME)
PACKAGE_STAGE := $(DIST_DIR)/package

BUILD_INFO := Sources/shared/BuildInfo.swift

BUNDLE_ID ?= com.gi8lino.EasyBar
VERSION ?= dev
ARCH ?= universal
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

ifeq ($(ARCH),universal)
ARCHES := arm64 x86_64
else ifeq ($(ARCH),arm64)
ARCHES := arm64
else ifeq ($(ARCH),x86_64)
ARCHES := x86_64
else
$(error Unsupported ARCH '$(ARCH)'. Use arm64, x86_64, or universal)
endif

.DEFAULT_GOAL := help

.PHONY: help all prepare-version build bundle package release app cli clean clean-dist run dev \
        build-app build-calendar-agent build-network-agent build-cli copy-resources verify stamp-plist sign notarize \
        print-arch print-version print-latest-tag print-package-sha256 \
        tag-patch tag-minor tag-major push-tags

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

all: build ## Build the default artifacts.

prepare-version: ## Generate Sources/shared/BuildInfo.swift with the selected VERSION.
	@mkdir -p "$(dir $(BUILD_INFO))"
	@printf '%s\n' 'import Foundation' > "$(BUILD_INFO)"
	@printf '\n' >> "$(BUILD_INFO)"
	@printf '%s\n' '/// Build-time version information shared by the app and CLI.' >> "$(BUILD_INFO)"
	@printf '%s\n' 'public enum BuildInfo {' >> "$(BUILD_INFO)"
	@printf '%s\n' '    /// The application version embedded at build time.' >> "$(BUILD_INFO)"
	@printf '%s\n' '    public static let appVersion = "$(VERSION)"' >> "$(BUILD_INFO)"
	@printf '%s\n' '}' >> "$(BUILD_INFO)"

build: bundle ## Build the app bundle and CLI for the selected ARCH.

app: prepare-version ## Build only the app executable for the selected ARCH.
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)

cli: prepare-version ## Build only the CLI executable for the selected ARCH.
	@$(MAKE) --no-print-directory build-cli ARCH=$(ARCH) VERSION=$(VERSION)

bundle: prepare-version clean-dist ## Build the .app bundle and CLI into dist/.
	@mkdir -p "$(APP_MACOS)" "$(APP_RESOURCES)" "$(DIST_DIR)"
	@$(MAKE) --no-print-directory build-app ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-calendar-agent ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-network-agent ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory build-cli ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory copy-resources ARCH=$(ARCH)
	@cp "$(PLIST_TEMPLATE)" "$(PLIST)"
	@$(MAKE) --no-print-directory stamp-plist VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@chmod +x "$(APP_BIN)" "$(CALENDAR_AGENT_BIN)" "$(NETWORK_AGENT_BIN)" "$(CLI_BIN)"
	@$(MAKE) --no-print-directory sign CODESIGN_IDENTITY='$(CODESIGN_IDENTITY)'
	@$(MAKE) --no-print-directory notarize CODESIGN_IDENTITY='$(CODESIGN_IDENTITY)' NOTARYTOOL_PROFILE='$(NOTARYTOOL_PROFILE)' NOTARY_SUBMIT='$(NOTARY_SUBMIT)'
	@$(MAKE) --no-print-directory verify

package: bundle ## Create the release ZIP consumed by the Homebrew formula.
	@rm -rf "$(PACKAGE_STAGE)" "$(PACKAGE_ZIP)"
	@mkdir -p "$(PACKAGE_STAGE)"
	@cp -R "$(APP_BUNDLE)" "$(PACKAGE_STAGE)/EasyBar.app"
	@cp "$(CALENDAR_AGENT_BIN)" "$(PACKAGE_STAGE)/EasyBarCalendarAgent"
	@cp "$(NETWORK_AGENT_BIN)" "$(PACKAGE_STAGE)/EasyBarNetworkAgent"
	@cp "$(CLI_BIN)" "$(PACKAGE_STAGE)/easybarctl"
	@cd "$(PACKAGE_STAGE)" && zip -qry "../$(PACKAGE_NAME)" "EasyBar.app" "EasyBarCalendarAgent" "EasyBarNetworkAgent" "easybarctl"
	@rm -rf "$(PACKAGE_STAGE)"
	@echo "Created $(PACKAGE_ZIP)"

release: package ## Build the zipped release artifact.
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

copy-resources: ## Internal target: copy SwiftPM resource bundles into the app bundle.
	@rm -rf "$(APP_RESOURCE_BUNDLE)"
ifeq ($(ARCH),universal)
	@cp -R ".build/arm64-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
else
	@cp -R ".build/$(ARCH)-apple-macosx/release/$(RESOURCE_BUNDLE_NAME)" "$(APP_RESOURCE_BUNDLE)"
endif

stamp-plist: ## Internal target: stamp version and bundle ID into Info.plist.
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier $(BUNDLE_ID)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(VERSION)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable $(APP_EXEC)' "$(PLIST)"
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true
	@/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName $(APP_NAME)' "$(PLIST)" >/dev/null 2>&1 || true

sign: ## Sign the app bundle, calendar agent, and CLI. Set CODESIGN_IDENTITY for Developer ID builds.
	@if [ "$(CODESIGN_IDENTITY)" = "-" ]; then \
		echo "Signing artifacts with ad-hoc identity"; \
		codesign --force --deep --sign - "$(APP_BUNDLE)"; \
		codesign --force --sign - "$(CALENDAR_AGENT_BIN)"; \
		codesign --force --sign - "$(NETWORK_AGENT_BIN)"; \
		codesign --force --sign - "$(CLI_BIN)"; \
	else \
		echo "Signing artifacts with $(CODESIGN_IDENTITY)"; \
		codesign --force --deep --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(APP_BUNDLE)"; \
		codesign --force --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(CALENDAR_AGENT_BIN)"; \
		codesign --force --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(NETWORK_AGENT_BIN)"; \
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
	@file "$(CALENDAR_AGENT_BIN)"
	@file "$(NETWORK_AGENT_BIN)"
	@file "$(CLI_BIN)"
	@test -f "$(PLIST)"
	@test -d "$(APP_RESOURCE_BUNDLE)"
	@echo "Info.plist:"
	@plutil -p "$(PLIST)"
	@echo "Packaged app root:"
	@ls -1 "$(APP_BUNDLE)"
	@echo "Packaged Contents:"
	@ls -1 "$(APP_CONTENTS)"
	@echo "Packaged Resources:"
	@ls -1 "$(APP_RESOURCES)" 2>/dev/null || true

run: bundle ## Build, start local agents, and open the app bundle.
	@nohup "$(CALENDAR_AGENT_BIN)" >/tmp/easybar-calendar-agent.dev.log 2>&1 &
	@nohup "$(NETWORK_AGENT_BIN)" >/tmp/easybar-network-agent.dev.log 2>&1 &
	@open "$(APP_BUNDLE)"

dev: prepare-version ## Fast debug run without bundling.
	@EASYBAR_DEBUG=1 $(SWIFT_BUILD_DEBUG) --product $(APP_PRODUCT)
	@EASYBAR_DEBUG=1 swift run -c debug $(APP_PRODUCT)

##@ Cleanup

clean-dist: ## Remove dist/.
	@rm -rf "$(DIST_DIR)"

clean: ## Remove dist/, .build, and generated BuildInfo.swift.
	@rm -rf "$(DIST_DIR)" ".build"
	@rm -f "$(BUILD_INFO)"

##@ Info

print-arch: ## Print the selected ARCH.
	@echo "$(ARCH)"

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
