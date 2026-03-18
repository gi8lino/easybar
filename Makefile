APP_NAME := EasyBar
APP_EXEC := EasyBar
APP_PRODUCT := EasyBar
CLI_PRODUCT := easybarctl
RESOURCE_BUNDLE_NAME := $(APP_NAME)_$(APP_PRODUCT).bundle

DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_BIN := $(APP_MACOS)/$(APP_EXEC)
CLI_BIN := $(DIST_DIR)/$(CLI_PRODUCT)
PLIST_TEMPLATE := packaging/Info.plist
PLIST := $(APP_CONTENTS)/Info.plist
APP_RESOURCE_BUNDLE := $(APP_BUNDLE)/$(RESOURCE_BUNDLE_NAME)

PACKAGE_NAME := $(APP_NAME)-$(VERSION).zip
PACKAGE_ZIP := $(DIST_DIR)/$(PACKAGE_NAME)
PACKAGE_STAGE := $(DIST_DIR)/package

BUILD_INFO := Sources/shared/BuildInfo.swift

BUNDLE_ID ?= com.example.EasyBar
VERSION ?= dev
ARCH ?= universal

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
        build-app build-cli copy-resources verify stamp-plist sign \
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
	@$(MAKE) --no-print-directory build-cli ARCH=$(ARCH) VERSION=$(VERSION)
	@$(MAKE) --no-print-directory copy-resources ARCH=$(ARCH)
	@cp "$(PLIST_TEMPLATE)" "$(PLIST)"
	@$(MAKE) --no-print-directory stamp-plist VERSION=$(VERSION) BUNDLE_ID=$(BUNDLE_ID)
	@chmod +x "$(APP_BIN)" "$(CLI_BIN)"
	@$(MAKE) --no-print-directory sign
	@$(MAKE) --no-print-directory verify

package: bundle ## Create the release ZIP consumed by the Homebrew formula.
	@rm -rf "$(PACKAGE_STAGE)" "$(PACKAGE_ZIP)"
	@mkdir -p "$(PACKAGE_STAGE)"
	@cp -R "$(APP_BUNDLE)" "$(PACKAGE_STAGE)/EasyBar.app"
	@cp "$(CLI_BIN)" "$(PACKAGE_STAGE)/easybarctl"
	@cd "$(PACKAGE_STAGE)" && zip -qry "../$(PACKAGE_NAME)" "EasyBar.app" "easybarctl"
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

copy-resources: ## Internal target: copy SwiftPM resource bundles into the app bundle root.
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

sign: ## Ad-hoc sign the bundle for local launching.
	@codesign --force --deep --sign - "$(APP_BUNDLE)" >/dev/null 2>&1 || true

verify: ## Show the built binary architectures and packaged resources.
	@echo "Built $(ARCH) artifacts:"
	@file "$(APP_BIN)"
	@file "$(CLI_BIN)"
	@echo "Packaged app root:"
	@ls -1 "$(APP_BUNDLE)"
	@echo "Packaged Contents:"
	@ls -1 "$(APP_CONTENTS)"
	@echo "Packaged Resources:"
	@ls -1 "$(APP_RESOURCES)"

run: bundle ## Build and open the app bundle.
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
