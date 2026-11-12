{
  description = "A Nix-flake-based Go development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # unstable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      goVersion = 27; # Change this to update the whole stack

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        go = final."go_1_${toString goVersion}";
      };

      packages = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default = pkgs.buildGoModule {
            pname = "montrose";
            version = "1.2.1";
            src = ./.;
            vendorHash = "sha256-csjga/uxJMtqH3Zxf02/kFhxqO22/oSNLlUWSd3s1D8=";
            postInstall = ''
              mkdir -p $out/share/montrose
              cp -r public $out/share/montrose/
            '';
          };
        }
      );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.montrose;
          site = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          options.services.montrose = {
            enable = lib.mkEnableOption "the Montrose Millwork website";
          };

          config = lib.mkIf cfg.enable {
            systemd.services.montrose = {
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                ExecStart = "${site}/bin/montRose";
                WorkingDirectory = "${site}/share/montrose";
                DynamicUser = true;
                Restart = "on-failure";
              };
            };
          };
        };

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              # go (version is specified by overlay)
              go

              # goimports, godoc, etc.
              gotools
              gcc
              air
              templ

              # https://github.com/golangci/golangci-lint
              golangci-lint

              self.formatter.${system}
            ];
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}
