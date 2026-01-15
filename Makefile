.PHONY: sync configure install uninstall help

# Default target
sync:
	@./sync.sh sync

configure:
	@./sync.sh configure

install:
	@echo "Installing amp-sync..."
	@chmod +x sync.sh
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(CURDIR)/sync.sh $(HOME)/.local/bin/amp-sync
	@echo ""
	@echo "✅ Installed! Make sure ~/.local/bin is in your PATH"
	@echo ""
	@echo "Add to your .zshrc or .bashrc if not already present:"
	@echo '  export PATH="$$HOME/.local/bin:$$PATH"'
	@echo ""
	@echo "Then run: amp-sync configure"

uninstall:
	@rm -f $(HOME)/.local/bin/amp-sync
	@rm -rf $(HOME)/.config/amplifier-sync
	@echo "✅ Uninstalled"

help:
	@./sync.sh help
