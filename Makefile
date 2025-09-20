SHELL := /bin/bash
TS := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
CONSTITUTION := docs/Constitution.md
ADR1 := docs/ADR-0001-constitution-adoption.md
CHR_DIR := chronicle
CAN_DIR := guardian/canonical
CAN_FILE := $(CAN_DIR)/constitution.sha256
ADP_JSON := chronicle/2025-09-19T-constitution-adoption.json

.PHONY: setup hashes seal-constitution verify
setup:
	mkdir -p $(CAN_DIR) $(CHR_DIR)/agents $(CHR_DIR)/diffs $(CHR_DIR)/telemetry scripts ci
	@echo "✅ Setup folders ready."

hashes:
	bash scripts/sha256sum_file.sh $(CONSTITUTION) | awk '{print $$1}' > $(CAN_FILE)
	@echo "constitution_hash=$$(cat $(CAN_FILE))"
	bash scripts/sha256sum_file.sh $(ADR1) | awk '{print $$1}' > /tmp/adr1.sha
	@echo "adr_hash=$$(cat /tmp/adr1.sha)"

seal-constitution:
	@test -f $(CAN_FILE) || (echo "Run 'make hashes' first." && exit 1)
	bash scripts/fill_chronicle_placeholders.sh --constitution $(CONSTITUTION) --adr $(ADR1) --entry $(ADP_JSON)
	@echo "✅ Chronicle entry filled."

verify:
	bash scripts/verify_constitution.sh $(CONSTITUTION) $(CAN_FILE)
