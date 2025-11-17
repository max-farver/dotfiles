{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = [
    pkgs.obsidian
    pkgs.gimp
    # inputs.affinity-nix.packages.x86_64-linux.v3
  ];

  programs.thunderbird = {
    enable = true;
    # settings applied to ALL profiles (optional)
    settings = {
      "privacy.donottrackheader.enabled" = true;
    };

    profiles."default" = {
      isDefault = true;

      # optional: order accounts in the folder pane
      accountsOrder = [
        "gmail"
      ];
    };
  };

  accounts.email.accounts."gmail" = {
    primary = true;
    realName = "Max Farver";
    address = "mfarver99@gmail.com";
    userName = "mfarver99@gmail.com";

    thunderbird = {
      enable = true; # generate thunderbird config for this account
      profiles = [ "default" ]; # attach to that profile
    };
  };

}
