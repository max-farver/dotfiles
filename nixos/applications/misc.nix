{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    obsidian
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
