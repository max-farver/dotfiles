{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    neovim

    go
    cargo
    lua
    lua-language-server
    luajitPackages.luarocks
    markdownlint-cli2
    nodejs_24
    zulu24
    php
    prettier
    ruby
    rbenv
    python312
    python312Packages.pip
    python312Packages.debugpy
    uv
    julia
    gcc
    nil
    typescript-language-server
    tree-sitter
  ];
}
