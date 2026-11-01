# Godot 4.7 Web build and deployment.

GODOT ?= godot
BUILD_DIR ?= build
DEPLOY_DIR ?= ..
BROTLI_QUALITY ?= 11

WEB_DIR := $(BUILD_DIR)/html
WEB_ENTRY := $(WEB_DIR)/godot.html
WEB_COMPRESS := godot.html godot.js godot.wasm godot.pck
DEPLOY_FILES := \
	godot.html godot.html.br godot.js godot.js.br \
	godot.wasm godot.wasm.br godot.pck godot.pck.br \
	godot.png godot.icon.png godot.apple-touch-icon.png \
	godot.audio.worklet.js godot.audio.position.worklet.js

.PHONY: help all import check web deploy clean clean-deploy
.DEFAULT_GOAL := web

help:
	@echo 'make web          Import assets and export build/html/godot.html'
	@echo 'make deploy       Build and copy Godot files into DEPLOY_DIR (default: ..)'
	@echo 'make check        Import assets and check the main scene headlessly'
	@echo 'make clean        Remove the local build/ directory'
	@echo 'make clean-deploy Remove only the Godot export files from DEPLOY_DIR'

all: web

import:
	$(GODOT) --headless --editor --import --quit

check: import
	@output=$$(mktemp); \
	$(GODOT) --headless --quit-after 5 > "$$output" 2>&1; status=$$?; \
	cat "$$output"; \
	if [ $$status -ne 0 ] || grep -Eq 'SCRIPT ERROR|(^|[[:space:]])ERROR:' "$$output"; then \
		rm -f "$$output"; exit 1; \
	fi; \
	rm -f "$$output"

web: import
	@mkdir -p "$(WEB_DIR)"
	@touch "$(BUILD_DIR)/.gdignore"
	$(GODOT) --headless --export-release Web "$(WEB_ENTRY)"
	@echo "Web build: $(WEB_ENTRY)"

deploy: web
	@mkdir -p "$(DEPLOY_DIR)"
	cp -f "$(WEB_DIR)"/godot.* "$(DEPLOY_DIR)/"
	cd "$(DEPLOY_DIR)" && brotli -k -f -q $(BROTLI_QUALITY) $(WEB_COMPRESS)
	@echo "Deployed Godot build to $(DEPLOY_DIR)/godot.html"

clean:
	rm -rf "$(BUILD_DIR)"

clean-deploy:
	@for file in $(DEPLOY_FILES); do \
		if [ -e "$(DEPLOY_DIR)/$$file" ]; then rm -v "$(DEPLOY_DIR)/$$file"; fi; \
	done
