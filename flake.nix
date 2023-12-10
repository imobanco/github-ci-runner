{
  description = "Este é o nix (com flakes) para o ambiente de desenvolvimento do github-ci-runner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
    podman-rootless.url = "github:ES-Nix/podman-rootless/from-nixpkgs";

    podman-rootless.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    allAttrs@{ self
    , nixpkgs
    , flake-utils
    , podman-rootless
    }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        name = "github-ci-runner";

        pkgsAllowUnfree = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
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

        # Utilized by `nix run .#<name>`
        apps.vm = {
          type = "app";
          program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-nixos-vm";
        };

        # nix fmt
        formatter = pkgsAllowUnfree.nixpkgs-fmt;

        /*
        packages.default = packages.${name};
        apps.${name} = flake-utils.lib.mkApp {
          inherit name;
          drv = packages.${name};
        };
        */

        devShells.default = pkgsAllowUnfree.mkShell {
          buildInputs = with pkgsAllowUnfree; [
            bashInteractive
            coreutils
            curl
            gettext
            gnumake
            hack
            httpie
            jq
            patchelf
            podman-rootless.packages.${system}.podman
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
            || nix build --impure --out-link .profiles/nixosConfigurations."$system".vm.config.system.build.vm .#nixosConfigurations.vm.config.system.build.vm


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

          ({ config, nixpkgs, pkgs, lib, modulesPath, ... }:
            let
              nixuserKeys = "ssh-ed25519 AAAAC3NzaC1lZD...";
            in
            {
              # Internationalisation options
              i18n.defaultLocale = "en_US.UTF-8";
              # i18n.defaultLocale = "pt_BR.UTF-8";
              console.keyMap = "br-abnt2";

              # Why
              # nix flake show --impure .#
              # break if it does not exists?
              # Use systemd boot (EFI only)
              boot.loader.systemd-boot.enable = true;
              fileSystems."/" = { device = "/dev/hda1"; };

              virtualisation.vmVariant = {
                virtualisation.useNixStoreImage = false;
                virtualisation.writableStore = true; # TODO: hardening

                virtualisation.docker.enable = true;

                programs.dconf.enable = true;
                # security.polkit.enable = true; # TODO: hardening?

                virtualisation.memorySize = 1024 * 2; # Use MiB memory.
                virtualisation.diskSize = 1024 * 16; # Use MiB memory.
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
                  btop
                  coreutils
                  direnv
                  file
                  git
                  gnumake
                  openssh
                  starship
                  which

                  github-runner
                  curl
                  jq
                  httpie

                  (
                    writeScriptBin "start-github-runner-with-pat" ''
                      #! ${pkgs.runtimeShell} -e

                      PAT="$1"
                      # https://github.com/actions/runner/issues/323#issuecomment-583640437
                      export ACTIONS_RUNNER_INPUT_REPLACE=Y

                      config.sh \
                      --unattended \
                      --url https://github.com/imobanco/github-ci-runner \
                      --pat "$PAT" \
                      --ephemeral \
                      --replace \
                      && run.sh
                    ''
                  )

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
                services.github-runner.enable = true;
                services.github-runner.url = "https://github.com/ORG_NAME";
                services.github-runner.tokenFile = config.sops.secrets."github-runner/token".path;
                services.github-runner.extraPackages = with pkgs; [ config.virtualisation.docker.package ];
                virtualisation.docker.enable = true;
                systemd.services.github-runner.serviceConfig.SupplementaryGroups = [ "docker" ];
              */

              programs.zsh = {
                enable = true;
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

              # Hack to fix annoying zsh warning, too overkill probably
              # https://www.reddit.com/r/NixOS/comments/cg102t/how_to_run_a_shell_command_upon_startup/eudvtz1/?utm_source=reddit&utm_medium=web2x&context=3
              systemd.user.services.fix-zsh-warning = {
                script = ''
                  echo "Fixing a zsh warning"
                  # https://stackoverflow.com/questions/638975/how-wdo-i-tell-if-a-regular-file-does-not-exist-in-bash#comment25226870_638985
                  test -f /home/nixuser/.zshrc || touch /home/nixuser/.zshrc && chown nixuser: -Rv /home/nixuser
                '';
                wantedBy = [ "default.target" ];
              };

              # https://nixos.wiki/wiki/Libvirt
              # https://discourse.nixos.org/t/set-up-vagrant-with-libvirt-qemu-kvm-on-nixos/14653
              boot.extraModprobeConfig = "options kvm_intel nested=1";

              # X configuration
              services.xserver.enable = true;
              services.xserver.layout = "br";

              services.xserver.displayManager.autoLogin.user = "nixuser";

              # https://nixos.org/manual/nixos/stable/#sec-xfce
              services.xserver.desktopManager.xfce.enable = true;
              services.xserver.desktopManager.xfce.enableScreensaver = false;

              services.xserver.videoDrivers = [ "qxl" ];

              # For copy/paste to work
              services.spice-vdagentd.enable = true;

              nixpkgs.config.allowUnfree = true;
              nix = {
                extraOptions = "experimental-features = nix-command flakes";
                package = pkgs.nixVersions.nix_2_10;
                readOnlyStore = true;
                registry.nixpkgs.flake = nixpkgs; # https://bou.ke/blog/nix-tips/

                nixPath = [
                  "nixpkgs=/etc/channels/nixpkgs"
                  "nixos-config=/etc/nixos/configuration.nix"
                ];
              };

              environment.etc."channels/nixpkgs".source = nixpkgs.outPath;

              environment.systemPackages = with pkgs; [
                bashInteractive
                openssh

                direnv
                nix-direnv
                fzf
                neovim
                nixos-option
                oh-my-zsh
                zsh
                zsh-autosuggestions
                zsh-completions

              ];

              system.stateVersion = "22.11";
            })

        ];
        specialArgs = { inherit nixpkgs; };
      };
    };
}
