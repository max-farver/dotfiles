{
  pkgs,
  inputs,
  ...
}:

let
  vercel-cli = pkgs.buildNpmPackage rec {
    pname = "vercel";
    version = "55.0.0";

    src = ./vercel-cli;
    npmDepsHash = "sha256-j9eNz2hQ0mRfFed8ESlG2lywHL1Y1iCIpq5qe+xu4y0=";
    npmDepsFetcherVersion = 2;

    npmFlags = [
      "--omit=dev"
      "--legacy-peer-deps"
    ];
    dontNpmBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/vercel" "$out/bin"
      cp -R node_modules package.json package-lock.json "$out/lib/vercel"

      makeWrapper ${pkgs.nodejs}/bin/node "$out/bin/vercel" \
        --add-flags "$out/lib/vercel/node_modules/vercel/dist/vc.js"
      ln -s "$out/bin/vercel" "$out/bin/vc"

      runHook postInstall
    '';
  };
in
{
  imports = [
    ./ai.nix
    ./git.nix
    ./litellm.nix
    ./neovim.nix
    ./tmux.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    csvlens
    freeze
    pandoc
    posting
    postgresql
    sqlite

    gnumake

    bat
    btop
    fd
    lsof
    jq
    ripgrep
    playwright-test
    vercel-cli
    inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs = {
    ghostty.enable = true;

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/home/mfarver/.config/nixos#framework16"; # sets NH_OS_FLAKE variable for you
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        keymap_mode = "auto";
        keymap_cursor = {
          emacs = "blink-block";
          vim_insert = "blink-block";
          vim_normal = "steady-block";
        };
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
      # Atuin owns Ctrl-R; keep fzf enabled without installing its bash history widget binding.
      historyWidget.bash.command = "";
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # zoxide = {
    #   enable = true;
    #   enableZshIntegration = true;
    # };

    bash.enable = true; # see note on other shells below
  };

}
