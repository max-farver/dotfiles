{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    neovim

    black
    cargo
    gcc
    go
    jdk
    lua
    lua-language-server
    luajitPackages.luarocks
    markdownlint-cli2
    nil
    nodejs_24
    openscad-lsp
    php
    prettier
    pyright
    python312
    python312Packages.pip
    python312Packages.debugpy
    ruff
    ruby
    rbenv
    uv
    typescript
    typescript-language-server
    tree-sitter
  ];
}
