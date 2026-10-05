# Makefile
CRYSTAL ?= crystal

VERSIONS := $(shell cut -d. -f1 src/llvmm/ext/llvm-versions.txt | sort -un)

.DEFAULT_GOAL := help
.PHONY: help spec matrix matrix-strict api-diff

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-18s\033[0m \033[2;37m%s\033[0m\n", $$1, $$2}'
	@echo ""
	@echo "  make spec-N       Run specs against llvm-config-N (e.g. make spec-23)"

spec:           ## Run specs against the default llvm-config
	$(CRYSTAL) spec

spec-%:
	LLVM_CONFIG=llvm-config-$* $(CRYSTAL) spec

matrix:         ## Run specs against every installed LLVM version (skips missing)
	@passed=0; skipped=0; failed=0; \
	for v in $(VERSIONS); do \
		if command -v llvm-config-$$v >/dev/null 2>&1; then \
			if LLVM_CONFIG=llvm-config-$$v $(CRYSTAL) spec > /tmp/llvmm-spec-$$v.log 2>&1; then \
				echo "llvm-$$v: PASS ($$(grep -oE '[0-9]+ examples' /tmp/llvmm-spec-$$v.log | head -1))"; \
				passed=$$((passed+1)); \
			else \
				echo "llvm-$$v: FAIL (log: /tmp/llvmm-spec-$$v.log)"; \
				failed=$$((failed+1)); \
			fi; \
		elif [ "$(STRICT)" = "1" ]; then \
			echo "llvm-$$v: FAIL (llvm-config-$$v not found)"; \
			failed=$$((failed+1)); \
		else \
			echo "llvm-$$v: SKIP (llvm-config-$$v not found)"; \
			skipped=$$((skipped+1)); \
		fi; \
	done; \
	echo "=="; \
	echo "matrix: $$passed passed, $$skipped skipped, $$failed failed"; \
	[ $$failed -eq 0 ]

matrix-strict:  ## Like matrix, but fail if any supported LLVM is missing
	@$(MAKE) --no-print-directory matrix STRICT=1

api-diff:       ## Diff bindings against llvm-c headers of TAG (default: latest release)
	$(CRYSTAL) run scripts/api_diff.cr $(if $(TAG),-- $(TAG))