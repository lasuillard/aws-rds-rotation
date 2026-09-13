{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
      {
        packages = {
          # Tools used in CI/CD pipelines
          inherit (pkgs)
            ;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pre-commit
            terraform
            awscli2
            ssm-session-manager-plugin
            postgresql_18
            uv
          ];

          shellHook = ''
            pre-commit install
          '';
        };
      }
    );
}
