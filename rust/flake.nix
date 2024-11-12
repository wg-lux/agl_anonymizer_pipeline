{
  description = "AGL Anonymizer Pipeline";

  inputs = {
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    flake-utils.follows = "cargo2nix/flake-utils";
    nixpkgs.follows = "cargo2nix/nixpkgs";
  };

  outputs = inputs: with inputs;
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [cargo2nix.overlays.default];
        };

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.75.0";
          packageFun = import ./Cargo.nix;
          extraRustComponents = ["rust-src"];
        };

      in rec {
        packages = {
          agl_anonymizer_pipeline = (rustPkgs.workspace.agl_anonymizer_pipeline {}).bin;
          default = packages.agl_anonymizer_pipeline;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            rustc
            maturin
            cargo2nix.packages.${system}.cargo2nix
            rust-analyzer
            clippy
            rustfmt
          ];
        };
      }
    );
}