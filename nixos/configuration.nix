# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # inputs.self.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
      inputs.self.overlays.stable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 0;
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        editor = true;
      };
    };
    initrd = {
      compressor = "cat"; #FIXME Compare across compressors
      verbose = false;
      systemd = {
        enable = true;
        network.wait-online.enable = false;
      };
    };
    consoleLogLevel = 0;
    plymouth = {
      enable = false; # For Boot Performance
    };
    modprobeConfig = {
      enable = true;
    };
    # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/modprobe.d/nvidia.conf
    extraModprobeConfig = "
      options nvidia NVreg_UsePageAttributeTable=1 \
                     NVreg_InitializeSystemMemoryAllocations=0 \
                     NVreg_RegistryDwords=RmEnableAggressiveVblank=1
    ";
    kernel = {
      sysctl = {
        # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/sysctl.d/70-cachyos-settings.conf
        "vm.swappiness" = 100;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_bytes" = 268435456;
        "vm.page-cluster" = 0;
        "vm.dirty_background_bytes" = 67108864;
        "vm.dirty_writeback_centisecs" = 1500;
        "kernel.nmi_watchdog" = 0;
        "kernel.unprivileged_userns_clone" = 1;
        "kernel.printk" = "3 3 3 3";
        "kernel.kptr_restrict" = 2;
        "net.core.netdev_max_backlog" = 4096;
        "fs.file-max" = 2097152;
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = {
      ntsync = true;
    };
    resumeDevice = "/dev/disk/by-uuid/8583f2df-34ce-4eae-b2b5-7da854b675ff";
    kernelParams = ["nvme_load=yes" "quiet" "splash" "udev.log_level=0" "nowatchdog"];
    blacklistedKernelModules = ["nouveau" "iTCO_wdt"];
  };

  networking = {
    nameservers = ["127.0.0.1" "::1"];
    hostName = "gaming-laptop"; # Define your hostname.
    networkmanager = {
      enable = true;
      dns = "none";
      wifi = {
        backend = "iwd";
      };
    };
    nftables = {
      enable = true;
    };
    firewall = {
      enable = true;
      # allowedTCPPorts = [
      #   80
      #   443
      # ];
      # allowedUDPPortRanges = [
      #   { from = 4000; to = 4007; }
      #   { from = 8000; to = 8010; }
      # ];
    };
  };

  systemd = {
    settings = {
      Manager = {
        DefaultTimeoutStartSec = "15s";
        DefaultTimeoutStopSec = "10s";
        DefaultLimitNOFILE = "2048:2097152";
      };
    };
    services = {
      rtkit-daemon = {
        serviceConfig = {
          LogLevelMax = "info";
        };
      };
      "user@" = {
        serviceConfig = {
          Delegate = "cpu cpuset io memory pids";
        };
      };
    };
    user = {
      extraConfig = "
        DefaultLimitNOFILE=1024:1048576
      ";
    };
    network = {
      wait-online = {
        enable = false;
      };
    };
    tmpfiles = {
      rules = [
        # Clear all coredumps that were created more than 3 days ago
        "d /var/lib/systemd/coredump 0755 root root 3d"
        # THP Shrinker has been added in the 6.12 Kernel
        # Default Value is 511
        # THP=always policy vastly overprovisions THPs in sparsely accessed memory areas, resulting in excessive memory pressure and premature OOM killing
        # 409 means that any THP that has more than 409 out of 512 (80%) zero filled filled pages will be split.
        # This reduces the memory usage, when THP=always used and the memory usage goes down to around the same usage as when madvise is used, while still providing an equal performance improvement
        "w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409"
        # Improve performance for applications that use tcmalloc
        # https://github.com/google/tcmalloc/blob/master/docs/tuning.md#system-level-optimizations
        "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
      ];
    };
  };

  # Time zone.
  time = {
    timeZone = "Asia/Tashkent";
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
      auto-optimise-store = true;

      substituters = lib.mkAfter [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = lib.mkAfter [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Select internationalisation properties.
  i18n = {
    # Mandatory
    defaultLocale = "en_US.UTF-8"; # Change default locale to English (US)
    # Extra
    extraLocales = ["uz_UZ.UTF-8/UTF-8"];
    # Optionally
    extraLocaleSettings = {
      # LC_ALL = "en_US.UTF-8"; # This overrides all other LC_* settings.
      LC_CTYPE = "en_US.UTF8";
      LC_ADDRESS = "uz_UZ.UTF-8";
      LC_MEASUREMENT = "uz_UZ.UTF-8";
      LC_MESSAGES = "en_US.UTF-8";
      LC_MONETARY = "uz_UZ.UTF-8";
      LC_NAME = "uz_UZ.UTF-8";
      LC_NUMERIC = "uz_UZ.UTF-8";
      LC_PAPER = "uz_UZ.UTF-8";
      LC_TELEPHONE = "uz_UZ.UTF-8";
      LC_TIME = "uz_UZ.UTF-8";
      LC_COLLATE = "uz_UZ.UTF-8";
    };
  };

  # Services section
  services = {
    # blueman = {
    #   enable = true;
    # };
    bpftune = {
      enable = true;
    };
    scx = {
      enable = true;
      scheduler = "scx_rustland";
      package = pkgs.scx.rustscheds;
    };
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    dnsproxy = {
      enable = true;
      settings = {
        # THE UPSTREAMS (IPv4 + IPv6)
        # We use hostnames for TLS verification and IPs for raw speed
        upstream = [
          "tls://dns.quad9.net" # Verified Domain
          "tls://9.9.9.9" # Primary IPv4
          "tls://149.112.112.112" # Secondary IPv4
          "tls://[2620:fe::fe]" # Primary IPv6
          "tls://[2620:fe::9]" # Secondary IPv6
        ];

        # PERFORMANCE: Query all upstreams and use the fastest response
        # Essential for gaming to minimize spikes.
        upstream-mode = "parallel";
        all-upstreams = true;
        fastest-addr = true;

        # SURVIVAL: Bootstrap IPs to resolve 'dns.quad9.net' initially
        bootstrap = [
          "9.9.9.9"
          "2620:fe::fe"
        ];

        # CACHING: Reduce internet traffic and speed up repeated lookups
        cache = true;
        cache-size = 4194304; # 4MB Cache (plenty for a laptop)
        cache-min-ttl = 600; # Keep records for at least 10 mins
        cache-optimistic = true; # Serve expired records while refreshing (Zero Latency)

        # INTERFACE: Listen on localhost for both IPv4 and IPv6
        listen-addrs = ["127.0.0.1" "::1"];
        listen-ports = [53];
        ipv6-disabled = false; # Keep this false for long-living support

        # PRIVACY & MODERNITY
        edns = true; # Better performance with CDNs
        dnssec = true; # Verify DNS records are untampered

        # INFO
        pprof = true;
      };
      # Additional launch flags
      # flags = [];
    };
    xserver = {
      # Enable X for GUI
      enable = true;
      videoDrivers = [
        "modesetting"
        "nvidia"
      ];
      xkb.layout = "us";
    };
    journald = {
      extraConfig = "
        [Journal]
        SystemMaxUse=50M
      ";
    };
    desktopManager = {
      plasma6 = {
        # Install KDE Plasma 6
        enable = true;
      };
    };
    displayManager = {
      # Default Session to plasma
      defaultSession = "plasma";
      autoLogin = {
        # Setup autoLogin
        enable = true;
        user = "monyx";
      };
      # Disable SDDM for Greetd
      sddm = {
        enable = false;
        # autoNumlock = true;
        # wayland = {
        #   enable = true;
        # };
      };
    };
    greetd = {
      enable = true;
      settings = {
        terminal = {
          vt = lib.mkDefault "current";
        };
        default_session = {
          user = "greeter";
          command = "${pkgs.tuigreet}/bin/tuigreet --user-menu -r -t";
        };
        initial_session = {
          command = "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland";
          user = "monyx";
        };
      };
    };
    switcherooControl = {
      enable = true;
    };
    printing = {
      # Enable CUPS service
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
        epson-escpr
        epson-escpr2
        gutenprint
        gutenprintBin
      ];
    };
    pipewire = {
      enable = true;
      pulse = {
        enable = true;
      };
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack = {
        enable = true;
      };
    };
    # Input library and touchpad settings
    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        accelProfile = "flat";
      };
      mouse = {
        accelProfile = "flat";
      };
    };
    flatpak = {
      enable = true;
    };
    openssh = {
      enable = true;
      openFirewall = true;
    };
    lact = {
      enable = true;
      settings = {
        version = 5;
        daemon = {
          log_level = "info";
          admin_group = "wheel";
          disable_clocks_cleanup = false;
        };
        apply_settings_timer = 5;
        gpus = {
          "10DE:2520-1458:1524-0000:01:00.0" = {
            fan_control_enabled = false;
            min_core_clock = 210;
            max_core_clock = 2100;
            gpu_clock_offsets = {
              "0" = 105;
            };
            mem_clock_offsets = {
              "0" = 900;
            };
          };
        };
        current_profile = null;
        auto_switch_profiles = false;
      };
    };
    udev = {
      enable = true;
      extraRules = ''
        # 20-audio-pm.rules
        # Disables power saving capabilities for snd-hda-intel when device is not
        # running on battery power. This is needed because it prevents audio cracks on
        # some hardware.
        ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", \
            RUN+="${pkgs.bash} -c 'touch /run/udev/snd-hda-intel-powersave; \
                [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && \
                echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave && \
                echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"

        SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", \
            RUN+="${pkgs.bash} -c 'echo $$(cat /run/udev/snd-hda-intel-powersave 2>/dev/null || \
                echo 10) > /sys/module/snd_hda_intel/parameters/power_save'"

        SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", \
            RUN+="${pkgs.bash} -c '[[ $$(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]] && \
                echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave; \
                echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"

        # 30-zram.rules
        # When used with ZRAM, it is better to prefer page out only anonymous pages,
        # because it ensures that they do not go out of memory, but will be just
        # compressed. If we do frequent flushing of file pages, that increases the
        # percentage of page cache misses, which in the long term gives additional
        # cycles to re-read the same data from disk that was previously in page cache.
        # This is the reason why it is recommended to use high values from 100 to keep
        # the page cache as hermetic as possible, because otherwise it is "expensive"
        # to read data from disk again. At the same time, uncompressing pages from ZRAM
        # is not as expensive and is usually very fast on modern CPUs.
        #
        # Also it's better to disable Zswap, as this may prevent ZRAM from working
        # properly or keeping a proper count of compressed pages via zramctl.
        ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", \
            RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"

        # 40-hpet-permissions.rules
        KERNEL=="rtc0", GROUP="audio"
        KERNEL=="hpet", GROUP="audio"
        # 50-sata.rules
        # SATA Active Link Power Management
        ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
            ATTR{link_power_management_policy}=="*", \
            ATTR{link_power_management_policy}="max_performance"
        # 60-ioscheduers.rules
        # HDD
        ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
            ATTR{queue/scheduler}="bfq"

        # SSD
        ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
            ATTR{queue/scheduler}="mq-deadline"

        # NVMe SSD
        ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
            ATTR{queue/scheduler}="none"
        # 69-hdparm.rules
        ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
            ATTRS{id/bus}=="ata", RUN+="${pkgs.hdparm} -B 254 -S 0 /dev/%k"
        # 71-nvidia.rules
        # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
        ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
            ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
            TEST=="power/control", ATTR{power/control}="auto"

        # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
        ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
            ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
            TEST=="power/control", ATTR{power/control}="on"

        # 99-cpu-dma-latency.rules
        DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
      '';
    };
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
    cpu = {
      intel = {
        updateMicrocode = true;
      };
    };
    nvidia = {
      open = true;
      modesetting = {
        enable = true;
      };
      dynamicBoost = {
        enable = true;
      };
      nvidiaPersistenced = false;
      nvidiaSettings = true;
      gsp = {
        enable = true;
      };
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # sync = {
        #   enable = true;
        # };
        intelBusId = "PCI:0@0:2:0";
        nvidiaBusId = "PCI:1@0:0:0";
      };
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Required for modern Intel GPUs (Xe iGPU and ARC)
        intel-media-driver # VA-API (iHD) userspace
        vpl-gpu-rt # oneVPL (QSV) runtime

        # Optional (compute / tooling):
        intel-compute-runtime-legacy1 # Legacy1 OpenCL
        # NOTE: 'intel-ocl' also exists as a legacy package; not recommended for Arc/Xe.
        libvdpau-va-gl # Only if you must run VDPAU-only apps
      ];
    };
  };

  security = {
    pam = {
      loginLimits = [
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "99";
        }
      ];
    };
    rtkit = {
      enable = true;
    };
    tpm2 = {
      enable = true;
      abrmd = {
        enable = true;
      };
      pkcs11 = {
        enable = true;
      };

      tctiEnvironment = {
        enable = true;
        interface = "tabrmd";
      };
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = false;
    users = {
      monyx = {
        isNormalUser = true;
        description = "monyx";
        extraGroups = ["wheel" "networkmanager" "video" "input" "audio"]; # Enable ‘sudo’ for the user.
        hashedPassword = "$y$j9T$wXdQSLqyNXpCehMmnmHvn0$cv4eLhzzVjjZmtZOjECicK/ecJL2vDGjN29iAdlVRP4";
        shell = pkgs.fish;
      };
      root = {
        hashedPassword = lib.mkForce "$y$j9T$ideJ4bo.KuXwECgFLZ45K0$puNfHyp1Fi9fg.iYb7ymtlr7HOrYgasERSLkPC1vav4";
      };
    };
  };

  xdg = {
    portal = {
      extraPortals = with pkgs; [xdg-desktop-portal-gtk kdePackages.xdg-desktop-portal-kde];
      config = {
        common = {
          default = "kde";
        };
      };
    };
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment = {
    variables = {
      EDITOR = "nano";
    };
    sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
    systemPackages = with pkgs; [
      git # For flakes!
      vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      wget
      nano
      fastfetch
      # home-manager # Fak gemini
      tuigreet # For greetd
      nix-tree
    ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs = {
    mtr = {
      enable = true;
    };
    gnupg = {
      agent = {
        enable = true;
        enableSSHSupport = true;
      };
    };
    nix-ld = {
      # https://wiki.nixos.org/wiki/Nix-ld
      enable = true;
      libraries = with pkgs; [
        ## Put here any library that is required when running a package
        ## ...
        ## Uncomment if you want to use the libraries provided by default in the steam distribution
        ## but this is quite far from being exhaustive
        ## https://github.com/NixOS/nixpkgs/issues/354513
        # (pkgs.runCommand "steamrun-lib" {} "mkdir $out; ln -s ${pkgs.steam-run.fhsenv}/usr/lib64 $out/lib")
      ];
    };
    fish = {
      enable = true;
      useBabelfish = true;
    };
    mosh = {
      enable = true;
      openFirewall = true;
      withUtempter = true;
    };
  };

  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  system.autoUpgrade = {
    enable = false;
    flake = "/etc/nixos"; # #FIXME WORKS AS SYMLINK
    # flags = [
    #   "--print-build-logs"
    # ];
    dates = "21:00";
    randomizedDelaySec = "15min";
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment? OR DONT CHANGE
}
