{
  # config, # Unused apparently
  pkgs,
  # inputs, # this option loses too
  ...
}: {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "monyx";
    homeDirectory = "/home/monyx";
    stateVersion = "25.11"; # Read the description or don't touch
    packages = with pkgs; [
      tree
      alejandra
      nix-du
      nix-tree
      nom
      manix
      nvtopPackages.full
      kdePackages.kcalc
      nvitop
      nil
      ayugram-desktop
      discordo
      pokemon-colorscripts
    ];
  };

  services = {
    easyeffects = {
      enable = true;
    };
  };

  programs = {
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 3";
      };
      flake = "/etc/nixos"; # #FIXME WORKS AS SYMLINK
    };
    fish = {
      enable = true;
      functions = {
        fish_greeting = {
          body = "${pkgs.pokemon-colorscripts}/bin/pokemon-colorscripts -r --no-title -s";
          onEvent = "fish_greeting";
        };
      };
    };
    firefox = {
      enable = true;
    };
    firefoxpwa = {
      enable = true;
    };
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        update_ms = 500;
      };
    };
    git = {
      enable = true;
      settings = {
        init = {
          defaultBranch = "master";
        };
        user = {
          name = "helix-nuked";
          email = "helix.nuked@proton.me";
        };
      };
    };
    home-manager = {
      # Let Home Manager install and manage itself.
      enable = true;
    };
    vesktop = {
      enable = true;
      settings = {
        arRPC = true;
        checkUpdates = false;
        minimizeToTray = true;
        hardwareAcceleration = true;
        hardwareVideoAcceleration = true;
        # customTitleBar = true; # It is bad.
        clickTrayToShowHide = true;
        discordBranch = "stable";
        enableTaskbarFlashing = true;
        openLinksWithElectron = false;
      };
    };
    vscode = {
      enable = true;
      package = pkgs.vscodium; # temporarily disabled
      mutableExtensionsDir = false;
      profiles = {
        "default" = {
          extensions = with pkgs.vscode-extensions; [
            kamadorueda.alejandra
            mhutchie.git-graph
            eamodio.gitlens
            arrterian.nix-env-selector
            jnoortheen.nix-ide
          ];
        };
      };
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
}
