{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    neovim

    go
    cargo
    lua
    luaPackages.lua-lsp
    luajitPackages.luarocks
    nodejs_24
    zulu24
    php
    ruby
    rbenv
    python312
    python312Packages.pip
    python312Packages.debugpy
    julia
    gcc
    nil
  ];
}
