{ pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    vim
  ];

  users.users.mfarver = {
    isNormalUser = true;
    description = "Max Farver";
    extraGroups = [ "wheel" ];
  };
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  services.timesyncd.enable = true;
}
