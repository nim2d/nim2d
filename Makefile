NIM ?= nim
VENV := .venv
MKDOCS := $(VENV)/bin/mkdocs
DOCS_DEPS := $(VENV)/.docs-deps

.PHONY: docs serve shots format format-check clean

# Build the static site, the guides plus the generated API reference, into
# site/. mkdocstrings-nim compiles a small Nim extractor on the first run.
docs: $(DOCS_DEPS)
	@$(MKDOCS) build --strict

# Serve the docs with live reload on http://127.0.0.1:8000/nim2d/.
serve: $(DOCS_DEPS)
	@$(MKDOCS) serve

# Set up the Python environment the docs build needs, from docs/requirements.txt.
$(DOCS_DEPS): docs/requirements.txt
	@python3 -m venv $(VENV)
	@$(VENV)/bin/pip install -q --upgrade pip
	@$(VENV)/bin/pip install -q -r docs/requirements.txt
	@touch $(DOCS_DEPS)

# Re-render the documentation screenshots into docs/assets. Opens a window and
# needs the SDL3 libraries plus Box2D (for the physics scene).
shots:
	@$(NIM) c -r --hints:off tools/docshots.nim

# Format every Nim source in place with nph (nimble install nph), or just
# report what would change.
format:
	@nph src tests examples tools

format-check:
	@nph --check src tests examples tools

clean:
	rm -rf site

include shaders.mk
