APP_NAME=EasyBar
CTL_NAME=easybarctl

BUILD_DIR=.build/debug

PREFIX=/usr/local
BIN_DIR=$(PREFIX)/bin

CONFIG_DIR=$(HOME)/.config/easybar
WIDGET_DIR=$(CONFIG_DIR)/widgets

.PHONY: build run install uninstall widgets clean reload

build:
	swift build

run:
	swift run $(APP_NAME)

install: build
	mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR)/$(APP_NAME) $(BIN_DIR)/easybar
	cp $(BUILD_DIR)/$(CTL_NAME) $(BIN_DIR)/easybarctl
	mkdir -p $(WIDGET_DIR)
	@echo "Installed EasyBar to $(BIN_DIR)"

widgets:
	mkdir -p $(WIDGET_DIR)
	cp widgets/*.lua $(WIDGET_DIR)/
	@echo "Installed example widgets"

reload:
	easybarctl reload_config

clean:
	swift package clean

uninstall:
	rm -f $(BIN_DIR)/easybar
	rm -f $(BIN_DIR)/easybarctl
	@echo "Removed EasyBar binaries"
