{
  description = "Este é o nix (com flakes) para o ambiente de desenvolvimento do github-ci-runner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
    podman-rootless.url = "github:ES-Nix/podman-rootless/from-nixpkgs";
    # sops-nix.url = "github:Mic92/sops-nix";

    # sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    podman-rootless.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    allAttrs@{ self
    , nixpkgs
    , ...
    }:
    {
      inherit (self) outputs;

      overlays.default = final: prev: {
        inherit self final prev;

        foo-bar = prev.hello;

        # https://fnordig.de/2023/07/24/old-ruby-on-modern-nix/
        # nodejs_16 = prev.nodejs_16.meta // { insecure = false; knownVulnerabilities = []; };
        github-runner =
          let
            ignoringVulns = x: x // { meta = (x.meta // { knownVulnerabilities = [ ]; }); };
          in
          prev.github-runner.override {
            nodejs_16 = prev.nodejs_16.overrideAttrs ignoringVulns;
          };
      };
    } //
    allAttrs.flake-utils.lib.eachDefaultSystem
      (system:
      let
        name = "github-ci-runner";

        pkgsAllowUnfree = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config = {
            allowUnfree = true;
          };
        };

        hack = pkgsAllowUnfree.writeShellScriptBin "hack" ''
          # Dont overwrite customised configuration

          # https://dev.to/ifenna__/adding-colors-to-bash-scripts-48g4
          echo -e '\n\n\n\e[32m\tAmbiente pronto!\e[0m\n'
          echo -e '\n\t\e[33mignore as proximas linhas...\e[0m\n\n\n'
        '';

        # https://gist.github.com/tpwrules/34db43e0e2e9d0b72d30534ad2cda66d#file-flake-nix-L28
        pleaseKeepMyInputs = pkgsAllowUnfree.writeTextDir "bin/.please-keep-my-inputs"
          (builtins.concatStringsSep " " (builtins.attrValues allAttrs));
      in
      rec {

        packages.vm = self.nixosConfigurations.vm.config.system.build.toplevel;

        /*
        # Utilized by `nix run .#<name>`

        rm -fv nixos.qcow2
        nix run --impure --refresh --verbose .#vm

        # Open the QMEU VM terminal and:
        start-github-runner-with-pat "$PAT"
        */
        apps.vm = {
          type = "app";
          program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-nixos-vm";
        };

        # nix fmt
        formatter = pkgsAllowUnfree.nixpkgs-fmt;

        devShells.default = pkgsAllowUnfree.mkShell {
          buildInputs = with pkgsAllowUnfree; [
            age
            allAttrs.podman-rootless.packages.${system}.podman
            bashInteractive
            coreutils
            curl
            gettext
            gh
            gnumake
            hack
            httpie
            jq
            patchelf
            sops
            ssh-to-age
          ];

          shellHook = ''
            # TODO: documentar esse comportamento,
            # devo abrir issue no github do nixpkgs
            export TMPDIR=/tmp

            echo "Entering the nix devShell no github-ci-runner"

            test -d .profiles || mkdir -v .profiles

            test -L .profiles/dev \
            || nix develop .# --profile .profiles/dev --command true

            test -L .profiles/dev-shell-default \
            || nix build $(nix eval --impure --raw .#devShells."$system".default.drvPath) --out-link .profiles/dev-shell-"$system"-default

            test -L .profiles/nixosConfigurations."$system".vm.config.system.build.vm \
            || nix build --out-link .profiles/nixosConfigurations."$system".vm.config.system.build.vm .#nixosConfigurations.vm.config.system.build.vm

            # For SOPS
            # test -d ~/.config/sops/age || mkdir -pv ~/.config/sops/age
            # test -f ~/.config/sops/age/keys.txt || age-keygen -o ~/.config/sops/age/keys.txt
            # https://github.com/getsops/sops/pull/860/files#diff-7b3ed02bc73dc06b7db906cf97aa91dec2b2eb21f2d92bc5caa761df5bbc168fR192
            # test -d secrets || mkdir -v secrets
            # test -f secrets/secrets.yaml.encrypted \
            # || sops \
            # --encrypt \
            # --age $(age-keygen -y ~/.config/sops/age/keys.txt) \
            # secrets/secrets.yaml > secrets/secrets.yaml.encrypted

            hack
          '';
        };
      })
    // {
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        # About system and maybe --impure
        # https://www.youtube.com/watch?v=90aB_usqatE&t=3483s
        system = builtins.currentSystem;

        modules = [
          # export QEMU_NET_OPTS="hostfwd=tcp::2200-:10022" && nix run .#vm
          # Then connect with ssh -p 2200 nixuser@localhost
          # ps -p $(pgrep -f qemu-kvm) -o args | tr ' ' '\n'
          ({ config, nixpkgs, pkgs, lib, modulesPath, ... }:
            let
              nixuserKeys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExR+PSB/jBwJYKfpLN+MMXs3miRn70oELTV3sXdgzpr";
            in
            {
              # Internationalisation options
              i18n.defaultLocale = "en_US.UTF-8";
              # i18n.defaultLocale = "pt_BR.UTF-8";
              console.keyMap = "br-abnt2";

              # Set your time zone.
              time.timeZone = "America/Recife";

              # Why
              # nix flake show --impure .#
              # break if it does not exists?
              # Use systemd boot (EFI only)
              boot.loader.systemd-boot.enable = true;
              fileSystems."/" = { device = "/dev/hda1"; };

              virtualisation.vmVariant =
                {

                  virtualisation.useNixStoreImage = false; # TODO: hardening
                  virtualisation.writableStore = true; # TODO: hardening

                  virtualisation.docker.enable = true;

                  programs.dconf.enable = true;
                  # security.polkit.enable = true; # TODO: hardening?

                  virtualisation.memorySize = 1024 * 8; # Use MiB memory.
                  virtualisation.diskSize = 1024 * 50; # Use MiB memory.
                  virtualisation.cores = 8; # Number of cores.
                  virtualisation.graphics = true;

                  virtualisation.resolution = lib.mkForce { x = 1024; y = 768; };

                  virtualisation.qemu.options = [
                    # Better display option
                    # TODO: -display sdl,gl=on
                    # https://gitlab.com/qemu-project/qemu/-/issues/761
                    "-vga virtio"
                    "-display gtk,zoom-to-fit=false"
                    # Enable copy/paste
                    # https://www.kraxel.org/blog/2021/05/qemu-cut-paste/
                    "-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on"
                    "-device virtio-serial-pci"
                    "-device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"

                    # https://serverfault.com/a/1119403
                    # "-device intel-iommu,intremap=on"

                    # "-net user,hostfwd=tcp::8090-::8080"
                  ];
                };

              users.users.root = {
                password = "root";
                initialPassword = "root";
                openssh.authorizedKeys.keyFiles = [
                  "${ pkgs.writeText "nixuser-keys.pub" "${toString nixuserKeys}" }"
                ];
              };

              # https://nixos.wiki/wiki/NixOS:nixos-rebuild_build-vm
              users.extraGroups.nixgroup.gid = 999;

              security.sudo.wheelNeedsPassword = false; # TODO: hardening
              users.users.nixuser = {
                isSystemUser = true;
                password = "101"; # TODO: hardening
                createHome = true;
                home = "/home/nixuser";
                homeMode = "0700";
                description = "The VM tester user";
                group = "nixgroup";
                extraGroups = [
                  "docker"
                  "kubernetes"
                  "kvm"
                  "libvirtd"
                  "nixgroup"
                  "podman"
                  "qemu-libvirtd"
                  "root"
                  "wheel"
                ];
                packages = with pkgs; [
                  awscli
                  bashInteractive
                  btop
                  coreutils
                  direnv
                  file
                  firefox
                  gh
                  git
                  gnumake
                  nix-info
                  openssh
                  openssl
                  starship
                  which
                  foo-bar

                ];
                shell = pkgs.zsh;
                uid = 1234;
                autoSubUidGidRange = true;

                openssh.authorizedKeys.keyFiles = [
                  "${ pkgs.writeText "nixuser-keys.pub" "${toString nixuserKeys}" }"
                ];

                openssh.authorizedKeys.keys = [
                  "${toString nixuserKeys}"
                ];
              };

              /*
                https://github.com/NixOS/nixpkgs/issues/169812
                https://github.com/actions/runner/issues/1882#issuecomment-1427930611
                nix shell nixpkgs#github-runner --command \
                sh \
                -c \
                'config.sh --url https://github.com/imobanco/github-ci-runner --pat "$PAT" --ephemeral && run.sh'
                config.sh --url https://github.com/imobanco/github-ci-runner --pat "$PAT" --ephemeral && run.sh
                TODO: https://www.youtube.com/watch?v=G5f6GC7SnhU
              */
              services.github-runner.enable = true;
              services.github-runner.ephemeral = true;
              services.github-runner.user = "nixuser";
              # services.github-runner.runnerGroup = "nixgroup";
              services.github-runner.url = "https://github.com/imobanco/github-ci-runner";
              # services.github-runner.tokenFile = config.sops.secrets."github-runner/token".path;
              services.github-runner.tokenFile = "/run/secrets/github-runner/nixos.token";
              services.github-runner.extraPackages = config.environment.systemPackages;
              #  services.github-runner.extraPackages = with pkgs; [
              #    config.virtualisation.docker.package
              #    hello
              #    # sudo
              #    procps
              #    python39
              #  ];
              virtualisation.docker.enable = true;
              virtualisation.podman.enable = true;
              systemd.services.github-runner.serviceConfig.SupplementaryGroups = [ "docker" ];

              systemd.user.services.populate-history-vagrant = {
                script = ''
                  echo "Started"

                  DESTINATION=/home/nixuser/.zsh_history

                  # TODO: https://stackoverflow.com/a/67169387
                  echo "journalctl -xeu github-runner-nixos.service" >> "$DESTINATION"
                  echo "systemctl status github-runner-nixos.service | cat" >> "$DESTINATION"
                  echo "run-github-runner && sudo systemctl restart github-runner-nixos.service" >> "$DESTINATION"

                  echo "Ended"
                '';
                wantedBy = [ "default.target" ];
              };

              /*
              https://github.com/vimjoyer/sops-nix-video/tree/25e5698044e60841a14dcd64955da0b1b66957a2
              https://github.com/Mic92/sops-nix/issues/65#issuecomment-929082304
              https://discourse.nixos.org/t/qmenu-secrets-sops-and-nixos/13621/8
              https://www.youtube.com/watch?v=1BquzE3Yb4I
              https://github.com/FiloSottile/age#encrypting-to-a-github-user
              https://devops.datenkollektiv.de/using-sops-with-age-and-git-like-a-pro.html
              sudo cat /run/secrets/example-key
              */
              /*
              sops.defaultSopsFile = ./secrets/secrets.yaml.encrypted;
              sops.defaultSopsFormat = "yaml";
              sops.gnupg.sshKeyPaths = [];
              sops.age.sshKeyPaths = [];
              sops.age.keyFile = ./secrets/keys.txt;
              sops.secrets.example-key = { };
              */

              # https://github.com/NixOS/nixpkgs/blob/3a44e0112836b777b176870bb44155a2c1dbc226/nixos/modules/programs/zsh/oh-my-zsh.nix#L119
              # https://discourse.nixos.org/t/nix-completions-for-zsh/5532
              # https://github.com/NixOS/nixpkgs/blob/09aa1b23bb5f04dfc0ac306a379a464584fc8de7/nixos/modules/programs/zsh/zsh.nix#L230-L231
              programs.zsh = {
                enable = true;
                shellAliases = {
                  vim = "nvim";
                };
                enableCompletion = true;
                autosuggestions.enable = true;
                syntaxHighlighting.enable = true;
                interactiveShellInit = ''
                  export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
                  export ZSH_THEME="agnoster"
                  export ZSH_CUSTOM=${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions
                  plugins=(
                            colored-man-pages
                            docker
                            git
                            #zsh-autosuggestions # Why this causes an warn?
                            #zsh-syntax-highlighting
                          )

                  # https://nixos.wiki/wiki/Fzf
                  source $ZSH/oh-my-zsh.sh

                  export DIRENV_LOG_FORMAT=""
                  eval "$(direnv hook zsh)"

                  eval "$(starship init zsh)"

                  export FZF_BASE=$(fzf-share)
                  source "$(fzf-share)/completion.zsh"
                  source "$(fzf-share)/key-bindings.zsh"
                '';

                ohMyZsh.custom = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
                promptInit = "";
              };

              fonts = {
                fontDir.enable = true;
                fonts = with pkgs; [
                  powerline
                  powerline-fonts
                ];
                enableDefaultFonts = true;
                enableGhostscriptFonts = true;
              };

              # Hack to fix annoying zsh warning, too overkill probably
              # https://www.reddit.com/r/NixOS/comments/cg102t/how_to_run_a_shell_command_upon_startup/eudvtz1/?utm_source=reddit&utm_medium=web2x&context=3
              # https://stackoverflow.com/questions/638975/how-wdo-i-tell-if-a-regular-file-does-not-exist-in-bash#comment25226870_638985
              systemd.user.services.fix-zsh-warning = {
                script = ''
                  test -f /home/nixuser/.zshrc || touch /home/nixuser/.zshrc && chown nixuser: -Rv /home/nixuser
                '';
                wantedBy = [ "default.target" ];
              };

              # Enable ssh
              services.sshd.enable = true;

              # https://github.com/NixOS/nixpkgs/issues/21332#issuecomment-268730694
              services.openssh = {
                allowSFTP = true;
                kbdInteractiveAuthentication = false;
                enable = true;
                forwardX11 = false;
                passwordAuthentication = false;
                permitRootLogin = "yes";
                ports = [ 10022 ];
                authorizedKeysFiles = [
                  "${ pkgs.writeText "nixuser-keys.pub" "${toString nixuserKeys}" }"
                ];
              };

              # https://nixos.wiki/wiki/Libvirt
              # https://discourse.nixos.org/t/set-up-vagrant-with-libvirt-qemu-kvm-on-nixos/14653
              boot.extraModprobeConfig = "options kvm_intel nested=1";

              services.qemuGuest.enable = true;

              # X configuration
              services.xserver.enable = true;
              services.xserver.layout = "br";

              services.xserver.displayManager.autoLogin.user = "nixuser";
              services.xserver.displayManager.sessionCommands = ''
                exo-open \
                  --launch TerminalEmulator \
                  --zoom=-3 \
                  --geometry 154x40
              '';

              # https://nixos.org/manual/nixos/stable/#sec-xfce
              services.xserver.desktopManager.xfce.enable = true;
              services.xserver.desktopManager.xfce.enableScreensaver = false;

              services.xserver.videoDrivers = [ "qxl" ];

              # For copy/paste to work
              services.spice-vdagentd.enable = true;

              nix = {
                extraOptions = "experimental-features = nix-command flakes";
                package = pkgs.nixVersions.nix_2_10;
                readOnlyStore = true;
                registry.nixpkgs.flake = nixpkgs; # https://bou.ke/blog/nix-tips/
                nixPath = [ "nixpkgs=${pkgs.path}" ];
              };

              environment.etc."channels/nixpkgs".source = "${pkgs.path}";

              environment.systemPackages = with pkgs; [
                bashInteractive
                openssh

                direnv
                fzf
                jq
                hello
                python3
                neovim
                nix-direnv
                nixos-option
                oh-my-zsh
                xclip
                zsh
                zsh-autosuggestions
                zsh-completions
                firefox
                which

                (
                  writeScriptBin "run-github-runner" ''
                    #! ${pkgs.runtimeShell} -e
                      sudo mkdir -pv -m 0700 /run/secrets/github-runner
                      sudo chown $(id -u):$(id -g) /run/secrets/github-runner
                      echo -n ghp_yyyyy > /run/secrets/github-runner/nixos.token
                  ''
                )
              ];

              # journalctl --user --unit create-custom-desktop-icons.service -b -f
              systemd.user.services.create-custom-desktop-icons = {
                script = ''
                  #! ${pkgs.runtimeShell} -e

                  echo "Started"

                  ln \
                    -sfv \
                    "${pkgs.xfce.xfce4-settings}"/share/applications/xfce4-terminal-emulator.desktop \
                    /home/nixuser/Desktop/xfce4-terminal-emulator.desktop

                  ln \
                    -sfv \
                    "${pkgs.firefox}"/share/applications/firefox.desktop \
                    /home/nixuser/Desktop/firefox.desktop

                  echo "Ended"
                '';
                wantedBy = [ "xfce4-notifyd.service" ];
              };

              # https://discourse.nixos.org/t/nixos-firewall-with-kubernetes/23673/2
              # networking.firewall.trustedInterfaces ??
              # networking.firewall.allowedTCPPorts = [ 80 8000 8080 8443 9000 9443 ];
              networking.firewall.enable = true; # TODO: hardening

              system.stateVersion = "22.11";
            })

          { nixpkgs.overlays = [ self.overlays.default ]; }

        ];

        specialArgs = { inherit nixpkgs allAttrs; };

      };
    };
}
