{
  description = "Este é o nix (com flakes) para o ambiente de desenvolvimento do github-ci-runner";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs_release_20_03.url = "github:NixOS/nixpkgs/release-20.03";
    podman-rootless.url = "github:ES-Nix/podman-rootless/from-nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs_release_20_03,
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

        pkgs_release_20_03 = import nixpkgs_release_20_03 {
          # O nix flake check --refresh --show-trace .#
          # quebra por conta de alguma(as) arquiteras
          # quebradas nos pacotes que estão sendo usados
          # deste canal.
          #
          # A discussão sobre como deve se terminar de resolver
          # cross compilação com nix + flakes ainda não é
          # completamente bem resolvida. Existem softwares
          # feitos para funcionar em uma única arquitera e só
          # foram pensados para esta, e no outro extremo
          # existem os que em teoria deveriam ser muito portáveis.

          system = "x86_64-linux";
          # inherit system;
          config = { allowUnfree = true; };
        };

        minimal-required-packages = with pkgsAllowUnfree; [
          bash
          coreutils
          gnumake
          podman-rootless.packages.${system}.podman
        ];

        # config = {
        #  projectDir = ./.;
        # };

        hack = pkgsAllowUnfree.writeShellScriptBin "hack" ''
          # Dont overwrite customised configuration

          # https://dev.to/ifenna__/adding-colors-to-bash-scripts-48g4
          echo -e '\n\n\n\e[32m\tAmbiente pronto!\e[0m\n'
          echo -e '\n\t\e[33mignore as proximas linhas...\e[0m\n\n\n'
        '';
      in
      rec {


        packages.default = packages.${name};

        packages.checkNixFormat = pkgsAllowUnfree.runCommand "check-nix-format" { } ''
          ${pkgsAllowUnfree.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}

          # For fix
          # find . -type f -iname '*.nix' -exec nixpkgs-fmt {} \;

          mkdir $out #sucess
        '';

        apps.${name} = flake-utils.lib.mkApp {
          inherit name;
          drv = packages.${name};
        };

        # env = pkgsAllowUnfree.poetry2nix.mkPoetryEnv config;

        devShells.default = pkgsAllowUnfree.mkShell {
          buildInputs = with pkgsAllowUnfree; [
            #(pkgsAllowUnfree.poetry2nix.mkPoetryEnv config)

            curl
            gnumake
            gettext
            hack
            patchelf
            podman-rootless.packages.${system}.podman
            jq
            httpie
#            catatonit
          ];

          shellHook = ''
            # TODO: documentar esse comportamento,
            # devo abrir issue no github do nixpkgs
            export TMPDIR=/tmp

            echo "Entering the nix devShell no github-ci-runner"

            hack
          '';
        };
      });
}
