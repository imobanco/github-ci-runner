{
  description = "Este é o nix (com flakes) para o ambiente de desenvolvimento do github-ci-runner";

  /*
    nix \
    flake \
    update \
    --override-input nixpkgs github:NixOS/nixpkgs/c1be43e8e837b8dbee2b3665a007e761680f0c3d \
    --override-input flake-utils github:numtide/flake-utils/4022d587cbbfd70fe950c1e2083a02621806a725
   */
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
      };

    } //
    (
      let
        # nix flake show --allow-import-from-derivation --impure --refresh .#
        suportedSystems = [
          "x86_64-linux"
          "aarch64-linux"
          # "aarch64-darwin"
        ];

      in
      allAttrs.flake-utils.lib.eachSystem suportedSystems
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

          packages.automatic-vm = pkgsAllowUnfree.writeShellApplication {
            name = "run-nixos-vm";
            runtimeInputs = with pkgsAllowUnfree; [ curl virt-viewer ];
            /*
              Pode ocorrer uma condição de corrida de seguinte forma:
              a VM inicializa (o processo não é bloqueante, executa em background)
              o spice/VNC interno a VM inicializa
              o remote-viewer tenta conectar, mas o spice não está pronto ainda

              TODO: idealmente não deveria ser preciso ter mais uma dependência (o curl)
                    para poder sincronizar o cliente e o server. Será que no caso de 
                    ambos estarem na mesma máquina seria melhor usar virt-viewer -fw?
              https://unix.stackexchange.com/a/698488
            */
            text = ''
              ${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-nixos-vm & PID_QEMU="$!"

              export VNC_PORT=3001

              for _ in web{0..50}; do
                if [[ $(curl --fail --silent http://localhost:"$VNC_PORT") -eq 1 ]];
                then
                  break
                fi
                # date +'%d/%m/%Y %H:%M:%S:%3N'
                sleep 0.2
              done;

              remote-viewer spice://localhost:"$VNC_PORT"

              kill $PID_QEMU
            '';
          };

          apps.run-github-runner = {
            type = "app";
            program = "${self.packages."${system}".automatic-vm}/bin/run-nixos-vm";
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
              virt-viewer
            ];

            shellHook = ''
              # TODO: documentar esse comportamento,
              # devo abrir issue no github do nixpkgs
              export TMPDIR=/tmp

              export HOSTNAME=$(hostname)

              echo "Entering the nix devShell no github-ci-runner"

              test -d .profiles || mkdir -v .profiles

              test -L .profiles/dev \
              || nix develop .# --profile .profiles/dev --command true

              test -L .profiles/dev-shell-default \
              || nix build $(nix eval --impure --raw .#devShells."$system".default.drvPath) --out-link .profiles/dev-shell-"$system"-default

              test -L .profiles/nixosConfigurations."$system".vm.config.system.build.vm \
              || nix build --impure --out-link .profiles/nixosConfigurations."$system".vm.config.system.build.vm .#nixosConfigurations.vm.config.system.build.vm

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
    )
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

              GH_HOSTNAME = builtins.getEnv "HOSTNAME";
              GH_TOKEN = builtins.getEnv "GH_TOKEN";
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

              # O Kernel de Fonseca é 5.*
              boot.kernelPackages = pkgs.linuxKernel.packages.linux_rt_5_15;

              virtualisation.vmVariant =
                {

                  virtualisation.useNixStoreImage = false; # TODO: hardening
                  virtualisation.writableStore = true; # TODO: hardening

                  virtualisation.docker.enable = true;

                  programs.dconf.enable = true;
                  # security.polkit.enable = true; # TODO: hardening?

                  virtualisation.memorySize = 1024 * 3; # Use MiB memory.
                  virtualisation.diskSize = 1024 * 25; # Use MiB memory.
                  virtualisation.cores = 3; # Number of cores.
                  virtualisation.graphics = true;

                  virtualisation.resolution = lib.mkForce { x = 1024; y = 768; };

                  virtualisation.qemu.options = [
                    # https://www.spice-space.org/spice-user-manual.html#Running_qemu_manually
                    # remote-viewer spice://localhost:3001

                    # "-daemonize" # How to save the QEMU PID?
                    "-machine vmport=off"
                    "-vga qxl"
                    "-spice port=3001,disable-ticketing=on"
                    "-device virtio-serial"
                    "-chardev spicevmc,id=vdagent,debug=0,name=vdagent"
                    "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
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
              services.github-runner.extraLabels = [ "nixos" ];
              # services.github-runner.extraPackages = config.environment.systemPackages;
              services.github-runner.extraPackages = with pkgs; [ iputils which ];
              services.github-runner.name = "${GH_HOSTNAME}";
              services.github-runner.replace = true;
              # services.github-runner.runnerGroup = "nixgroup"; # Apenas administradores da organização do github conseguem usar isso?
              services.github-runner.tokenFile = "/run/secrets/github-runner/nixos.token";
              services.github-runner.url = "https://github.com/Imobanco/github-ci-runner";
              services.github-runner.user = "nixuser";
              systemd.user.extraConfig = ''
                DefaultEnvironment="PATH=/run/current-system/sw/bin:/home/nixuser/.nix-profile/bin"
              '';
              services.github-runner.serviceOverrides = {
                ReadWritePaths = [
                  "/nix"
                  # "/nix/var/nix/profiles/per-user/" # https://github.com/cachix/cachix-ci-agents/blob/63f3f600d13cd7688e1b5db8ce038b686a5d29da/agents/linux.nix#L30C26-L30C59
                ];

                # NoNewPrivileges = false;
                # PrivateTmp = false;
                PrivateUsers = false;
                DynamicUser = false;
                PrivateDevices = false;
                PrivateMounts = false;
                AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_SYS_ADMIN" ];
                CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_SYS_ADMIN" ];
                RestrictSUIDSGID = false;
                DeviceAllow = [ "/dev/kvm" ];
                Environment = "PATH=/run/current-system/sw/bin:${lib.makeBinPath [ pkgs.iputils ]}"; # https://discourse.nixos.org/t/how-to-add-path-into-systemd-user-home-manager-service/31623/4
              };

              virtualisation.docker.enable = true;

              /*
                TODO: apenas na unidade do systemd,
                  na VM (no "terminal") o podman funciona!

                stat $(which newuidmap)
                stat $(which newgidmap)
                stat $(which /run/wrappers/bin/newuidmap)
                stat $(which /run/wrappers/bin/newgidmap)

                Relacionado?

                O sudo tb está "quebrado" nesse ambiente!
                sudo: The "no new privileges" flag is set, which
                prevents sudo from running as root.
                sudo: If sudo is running in a container, you may
                need to adjust the container configuration to
                disable the flag.
                https://github.com/imobanco/github-ci-runner/actions/runs/7410857271/job/20164052167#step:5:51

                cannot clone: Operation not permitted
                Error: cannot re-exec process
                Error: Process completed with exit code 125.
                https://github.com/imobanco/github-ci-runner/actions/runs/7410557206/job/20163140291#step:8:56
              */
              virtualisation.podman.enable = false;

              systemd.services.github-runner.serviceConfig.SupplementaryGroups = [ "docker" "podman" ];

              systemd.user.services.populate-history-vagrant = {
                script = ''
                  echo "Started"

                  DESTINATION=/home/nixuser/.zsh_history

                  # TODO: https://stackoverflow.com/a/67169387
                  echo "sudo systemctl cat github-runner-${GH_HOSTNAME}.service | cat" >> "$DESTINATION"
                  echo "journalctl -xeu github-runner-${GH_HOSTNAME}.service" >> "$DESTINATION"
                  echo "systemctl status github-runner-${GH_HOSTNAME}.service | cat" >> "$DESTINATION"
                  echo "save-pat && sudo systemctl restart github-runner-${GH_HOSTNAME}.service" >> "$DESTINATION"
                  echo "sudo systemctl restart github-runner-${GH_HOSTNAME}.service" >> "$DESTINATION"

                  echo "${GH_TOKEN}" > /run/secrets/github-runner/nixos.token

                  sudo systemctl restart github-runner-${GH_HOSTNAME}.service

                  echo "Ended"
                '';
                wantedBy = [ "default.target" ];
              };

              # journalctl -u prepare-secrets -b -f
              systemd.services.prepare-secrets = {
                script = ''
                  echo "starting prepare-secrets script"

                  # TODO: remover hardcoded
                  mkdir -pv -m 0700 /run/secrets/github-runner
                  chown nixuser:nixgroup /run/secrets/github-runner

                  echo End
                '';
                wantedBy = [ "multi-user.target" ];
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
                packages = with pkgs; [
                  powerline
                  powerline-fonts
                ];
                enableDefaultPackages = true;
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

              services.sshd.enable = true;

              # https://github.com/NixOS/nixpkgs/issues/21332#issuecomment-268730694
              services.openssh = {
                allowSFTP = true;
                settings.KbdInteractiveAuthentication = false;
                enable = true;
                # settings.ForwardX11 = false;
                settings.PasswordAuthentication = false;
                settings.PermitRootLogin = "yes";
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

              nixpkgs.config.allowUnfree = true;

              boot.readOnlyNixStore = true;

              nix = {
                extraOptions = "experimental-features = nix-command flakes";
                package = pkgs.nixVersions.nix_2_10;
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
                fzf
                jq
                hello
                # podman
                python3
                neovim
                nix-direnv
                nixos-option
                oh-my-zsh
                shadow
                xclip
                zsh
                zsh-autosuggestions
                zsh-completions
                firefox
                which

                (
                  writeScriptBin "save-pat" ''
                    #! ${pkgs.runtimeShell} -e
                      # sudo mkdir -pv -m 0700 /run/secrets/github-runner
                      # sudo chown $(id -u):$(id -g) /run/secrets/github-runner
                      # echo -n ghp_yyyyy > /run/secrets/github-runner/nixos.token

                      bash -lc \
                      '
                      read -sp "Please enter your github PAT:" MY_PAT
                      echo -n "$MY_PAT" > /run/secrets/github-runner/nixos.token
                      '
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

              networking.firewall.enable = true; # TODO: hardening

              system.stateVersion = "23.11";
            })

          { nixpkgs.overlays = [ self.overlays.default ]; }

        ];

        specialArgs = { inherit nixpkgs allAttrs; };

      };
    };
}
