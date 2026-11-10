_default:
    just --list

# Install deps and tools
install:
    pre-commit install

# Update dependencies and tools
update:
    nix flake update
    pre-commit autoupdate

alias up := update
