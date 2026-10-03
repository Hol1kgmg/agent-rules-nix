# List recipes
list:
    @just --list

# Install example rules into .claude/rules
rules:
    nix run .#rules-install-local

# Update flake.lock, then check
update:
    nix flake update
    nix flake check
