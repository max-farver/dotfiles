{ lib, pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  # Fresh servers receive a route through DHCP unless host-specific networking overrides it.
  networking.useDHCP = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # nixpkgs requires an explicit versioned Kanidm package even when its service is disabled.
  services.kanidm.package = pkgs.kanidm_1_9;

  services.timesyncd.enable = true;
}
