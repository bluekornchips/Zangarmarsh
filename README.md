# Zangarmarsh

## Overview

Shell profile setup automation that works for Bash and Zsh.

## Install

```bash
# Clone the repository
git clone https://github.com/bluekornchips/zangarmarsh.git
cd zangarmarsh

# Source the main script
source zangarmarsh.sh

# Add to your shell profile for permanent setup
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.bashrc
echo 'source /path/to/zangarmarsh/zangarmarsh.sh' >> ~/.zshrc

# Or use the provided Makefile for testing
make check  # Run all tests and linting
```

## Usage

```bash
# Test all components
make test-all

# Reload configuration
source ~/.bashrc  # or ~/.zshrc

# Available functions and aliases after sourcing:
# penv : Python virtual environment helper
# nvm : Node.js version manager (lazy-loaded)
# questlog : Agent instructions tool (alias)
# dalaran : Command history library tool (alias)
# trilliax : Cleanup tool (alias)
```
