# Makefile for grundle
# ====================

.PHONY: all build check test clean install uninstall help dev

# Default target
all: build

# Build the project
build:
	@echo "🫛 Building grundle..."
	gleam build

# Type check without building
check:
	@echo "🔍 Type checking..."
	gleam check

# Run tests
test:
	@echo "🧪 Running tests..."
	gleam test

# Create standalone binary
binary: build
	@echo "📦 Creating standalone binary..."
	gleam export erlang-shipment
	@mkdir -p dist
	@echo '#!/usr/bin/env bash' > dist/grundle
	@echo '# Standalone grundle binary' >> dist/grundle
	@echo 'SCRIPT_DIR="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" && pwd)"' >> dist/grundle
	@echo 'GRUNDLE_LIB="$$SCRIPT_DIR/../build/erlang-shipment"' >> dist/grundle
	@echo 'if ! command -v erl >/dev/null 2>&1; then' >> dist/grundle
	@echo '    echo "Error: Erlang is required but not installed."' >> dist/grundle
	@echo '    echo "Install with: nix-shell -p erlang"' >> dist/grundle
	@echo '    exit 1' >> dist/grundle
	@echo 'fi' >> dist/grundle
	@echo 'exec erl -noshell -pa "$$GRUNDLE_LIB"/*/ebin -s grundle main -s init stop -- "$$@"' >> dist/grundle
	@chmod +x dist/grundle
	@echo "✅ Binary created: dist/grundle"

# Install to system
install: binary
	@echo "📥 Installing grundle to /usr/local/bin..."
	@sudo cp dist/grundle /usr/local/bin/grundle
	@echo "✅ grundle installed! Try: grundle --help"

# Uninstall from system
uninstall:
	@echo "🗑️  Uninstalling grundle..."
	@sudo rm -f /usr/local/bin/grundle
	@echo "✅ grundle uninstalled"

# Development shell (requires Nix)
dev:
	@echo "🛠️  Entering development shell..."
	nix develop

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf build/ manifest.toml dist/
	@echo "✅ Clean complete"

# Run grundle with arguments
run:
	@gleam run -- $(ARGS)

# Quick test of the binary
test-binary: binary
	@echo "🧪 Testing binary..."
	@dist/grundle --help
	@echo "✅ Binary test passed"

# Package for distribution
package: clean binary
	@echo "📦 Creating distribution package..."
	@tar -czf grundle-$$(grep 'version =' gleam.toml | cut -d'"' -f2).tar.gz \
		dist/grundle build/erlang-shipment README.md USAGE_GUIDE.md
	@echo "✅ Package created: grundle-$$(grep 'version =' gleam.toml | cut -d'"' -f2).tar.gz"

# Help target
help:
	@echo "🫛 grundle Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build        - Build the project"
	@echo "  check        - Type check without building"  
	@echo "  test         - Run tests"
	@echo "  binary       - Create standalone binary in dist/"
	@echo "  install      - Install binary to /usr/local/bin"
	@echo "  uninstall    - Remove binary from /usr/local/bin"
	@echo "  clean        - Clean build artifacts"
	@echo "  dev          - Enter Nix development shell"
	@echo "  run ARGS=... - Run grundle with arguments"
	@echo "  test-binary  - Test the standalone binary"
	@echo "  package      - Create distribution tarball"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make binary"
	@echo "  make run ARGS='todo.md --to-ics output/'"
	@echo "  make install"