{
  description = "Este é o nix (com flakes) para o ambiente de desenvolvimento do github-ci-runner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
    podman-rootless.url = "github:ES-Nix/podman-rootless/from-nixpkgs";

    podman-rootless.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = allAttrs@{
    self,
    nixpkgs,
    flake-utils,
    podman-rootless
  }:
    flake-utils.lib.eachDefaultSystem (system:
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

            hack
          '';
        };
      });
}
