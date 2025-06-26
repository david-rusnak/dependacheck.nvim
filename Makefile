.PHONY: test test-file test-watch lint clean

# Run all tests
test:
	@echo "Running all tests..."
	@nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {sequential=true}"

# Run a specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/util_spec.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	@nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

# Watch for changes and run tests
test-watch:
	@echo "Watching for changes..."
	@while true; do \
		make test; \
		inotifywait -qre modify lua/ tests/ 2>/dev/null || sleep 2; \
	done

# Lint the code
lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		echo "Running luacheck..."; \
		luacheck lua/; \
	else \
		echo "luacheck not installed. Install with: luarocks install luacheck"; \
	fi

# Clean up temporary files
clean:
	@echo "Cleaning up..."
	@rm -rf /tmp/nvim/site/pack/packer/start/plenary.nvim
	@find . -name "*.swp" -delete
	@find . -name "*.swo" -delete

# Install test dependencies
install-test-deps:
	@echo "Installing test dependencies..."
	@if [ ! -d "/tmp/nvim/site/pack/packer/start/plenary.nvim" ]; then \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim /tmp/nvim/site/pack/packer/start/plenary.nvim; \
	fi

# Help
help:
	@echo "Available targets:"
	@echo "  test              - Run all tests"
	@echo "  test-file FILE=   - Run a specific test file"
	@echo "  test-watch        - Watch for changes and run tests"
	@echo "  lint              - Run luacheck on the code"
	@echo "  clean             - Clean up temporary files"
	@echo "  install-test-deps - Install test dependencies"
	@echo "  help              - Show this help message"