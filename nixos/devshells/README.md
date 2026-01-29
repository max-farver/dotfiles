# Nix Development Environment Templates

A collection of standalone Nix flake templates for reproducible development environments.

## Overview

This directory contains self-contained flake templates for various programming languages, making it easy to set up consistent development environments across projects. These templates follow the `the-nix-way/dev-templates` pattern, using `pkgs.mkShellNoCC` instead of `numtide/devshell` modules.

## Features

- **Standalone flakes** - Each template is a complete, self-contained flake
- **Reproducible environments** - Same tools and versions across all machines
- **Language-specific templates** - Pre-configured for Python, JavaScript/TypeScript, Rust, Go, and base tools
- **Direnv integration** - Automatic environment activation when entering directories
- **Cross-platform** - Supports x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin
- **No installation required** - Tools are available only in the project environment

## Directory Structure

```
devshells/
├── README.md                    # This file
├── base/                        # Base development environment
│   ├── flake.nix               # Flake with common dev tools
│   └── .envrc                  # Direnv configuration
├── python/                      # Python development environment
│   ├── flake.nix               # Python flake template
│   └── .envrc                  # Direnv configuration
├── javascript/                  # JavaScript/TypeScript environment
│   ├── flake.nix               # Node.js flake template
│   └── .envrc                  # Direnv configuration
├── rust/                        # Rust development environment
│   ├── flake.nix               # Rust flake template
│   └── .envrc                  # Direnv configuration
└── go/                          # Go development environment
    ├── flake.nix               # Go flake template
    └── .envrc                  # Direnv configuration
```

## Quick Start

### Creating a New Project

The easiest way to use these templates is via `nix flake init` or `nix flake new`:

```bash
# Initialize a new Python project in current directory
nix flake init --template ~/.config/nixos#python

# Create a new Rust project in a new directory
nix flake new --template ~/.config/nixos#rust ./my-rust-project

# Create a new Go project
nix flake new --template ~/.config/nixos#go ./my-go-project

# Create a project with base tools only
nix flake new --template ~/.config/nixos#base ./my-project
```

### Using the Devshell

Once you've created a project from a template:

```bash
cd <your-project>

# Option 1: Use nix develop
nix develop

# Option 2: Use direnv (recommended)
direnv allow
```

## Available Templates

### Base

Common development tools without language-specific packages.

**Tools included:**
- Version control: `git`, `gh`, `lazygit`
- Modern unix tools: `ripgrep`, `fd`, `bat`, `eza`
- File inspection: `jq`, `fzf`, `delta`
- Build tools: `gnumake`, `cmake`
- Utilities: `tree`, `htop`, `btop`

**Usage:**
```bash
nix flake init --template ~/.config/nixos#base
```

### Python

Complete Python development environment with modern tooling.

**Tools included:**
- Python 3.12
- `uv` - Fast Python package manager
- `black` - Code formatter
- `ruff` - Linter
- `pyright` - Type checker
- `pytest` - Testing framework
- `poetry` - Dependency management
- `pip` - Package installer

**Usage:**
```bash
nix flake init --template ~/.config/nixos#python
```

### Rust

Rust development environment with the standard toolchain.

**Tools included:**
- `rustc` - Rust compiler
- `cargo` - Package manager and build tool
- `rust-analyzer` - Language server
- `rustfmt` - Code formatter
- `clippy` - Linter

**Usage:**
```bash
nix flake init --template ~/.config/nixos#rust
```

### Go

Go development environment with essential tools.

**Tools included:**
- `go` - Go toolchain
- `gopls` - Language server
- `gofumpt` - Code formatter
- `delve` - Debugger
- `gotools` - Additional Go utilities

**Usage:**
```bash
nix flake init --template ~/.config/nixos#go
```

### JavaScript/TypeScript

Modern JavaScript and TypeScript development environment.

**Tools included:**
- Node.js 24
- TypeScript
- `pnpm` - Fast package manager
- `prettier` - Code formatter

**Usage:**
```bash
nix flake init --template ~/.config/nixos#javascript
```

## Customizing Templates

Each template is a self-contained flake.nix file. To customize a template for your project:

1. Initialize from a template
2. Edit the `flake.nix` file to add/remove packages or modify the shellHook
3. Update the environment with `nix develop` or `direnv reload`

### Example: Adding a package to Python template

```nix
# flake.nix
{
  description = "My Python project";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: {
    devShells = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          python312
          uv
          # Add more packages here
          python312Packages.numpy
          python312Packages.pandas
        ];

        shellHook = ''
          echo "My custom Python environment"
        '';
      };
    });
  };
}
```

### Combining Languages

You can easily combine tools from multiple templates:

```nix
packages = with pkgs; [
  # Python tools
  python312
  python312Packages.black

  # Node.js tools
  nodejs_24
  typescript
];
```

## Direnv Integration

Each template includes a `.envrc` file with `use flake` for automatic environment loading.

**How it works:**
1. Navigate to a project with `.envrc`
2. Direnv automatically loads the flake environment
3. When you leave the directory, it unloads

**Commands:**
- `direnv allow` - Authorize loading the environment
- `direnv deny` - Prevent loading the environment
- `direnv reload` - Reload the environment
- `direnv status` - Show environment status

## Listing Available Templates

To see all available templates in your flake:

```bash
nix flake show ~/.config/nixos
```

This will display all templates with their descriptions.

## Troubleshooting

### Template not found

Ensure your path is correct:
```bash
# Full path
nix flake init --template /home/mfarver/.config/nixos#python

# Or from anywhere
nix flake init --template ~/.config/nixos#python
```

### Direnv not loading

1. Check direnv is installed: `which direnv`
2. Check direnv is in your shell hooks
3. Try reloading: `direnv reload`
4. Authorize the .envrc: `direnv allow`

### Package not found

1. Search for the package: `nix search nixpkgs <package>`
2. Check the package name in [NixOS Search](https://search.nixos.org/packages)
3. Make sure you're using the correct nixpkgs channel

### Cross-platform issues

The templates support multiple architectures. If you're on an unsupported platform:
1. Add your system to the `supportedSystems` list in the template's flake.nix
2. Or modify the template for your specific needs

## Common Workflows

### Starting a New Python Project

```bash
# Create project directory
mkdir -p ~/projects/my-python-app
cd ~/projects/my-python-app

# Initialize from template
nix flake init --template ~/.config/nixos#python

# Activate environment
direnv allow

# Initialize Python project
uv init
```

### Starting a New TypeScript Project

```bash
# Create project directory
mkdir -p ~/projects/my-ts-app
cd ~/projects/my-ts-app

# Initialize from template
nix flake init --template ~/.config/nixos#javascript

# Activate environment
direnv allow

# Initialize project
pnpm init
```

### Adding Nix to an Existing Project

```bash
cd ~/existing-project

# Copy a template's flake.nix
cp ~/.config/nixos/devshells/python/flake.nix ./flake.nix

# Edit flake.nix to customize packages
# Copy .envrc for direnv integration
cp ~/.config/nixos/devshells/python/.envrc ./.envrc

# Activate
direnv allow
```

## Template Architecture

### Why mkShellNoCC instead of devshell modules?

This approach:
- **Simpler** - No module system or composition to understand
- **Standard** - Uses built-in Nix functionality
- **Portable** - Works across all Nix installations
- **Lightweight** - No external dependencies beyond nixpkgs

### Trade-offs

- Less DRY: Common tools are copied to each template (no base module)
- No commands feature: Simpler environment without devshell's command system
- Manual customization: Each template is self-contained

## Resources

- [Nix Flakes](https://nixos.wiki/wiki/Flakes) - Flakes documentation
- [nix-direnv](https://github.com/nix-community/nix-direnv) - Direnv integration
- [NixOS Search](https://search.nixos.org/packages) - Package search
- [the-nix-way/dev-templates](https://github.com/the-nix-way/dev-templates) - Inspiration for this pattern

## Contributing

Feel free to customize these templates for your needs:

1. Modify template files in `base/`, `python/`, etc.
2. Add new language templates
3. Update this README with your changes
4. Share improvements with your team
