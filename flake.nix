{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    devenv.url = "github:cachix/devenv/9b6566c51efa2fdd6c6e6053308bc3a1c6817d31";
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      packages.x86_64-linux.default = pkgs;

    in
    {
      # Combine devenv outputs under the same `devShells.${system}.default` package
      devShells.${system}.default = devenv.lib.mkShell {
        inherit pkgs;
        modules = [
          {
            packages = [
              pkgs.python311     
              pkgs.git
              pkgs.libcxx
              pkgs.python311Packages.numpy
              pkgs.python311Packages.transformers
              pkgs.python311Packages.torch
              pkgs.python311Packages.torchvision
              pkgs.python311Packages.torchaudio
              pkgs.python311Packages.spacy
              pkgs.python311Packages.spacy-lookups-data
              pkgs.python311Packages.opencv4
              pkgs.tesseract
              pkgs.python311Packages.pymupdf
            ];

            env = {
              GREET = "devenv";
              PROJECT_DIR = "${toString ./agl_anonymizer_pipeline}";
            };

            enterShell = ''
              echo "Entering shell for $PROJECT_DIR"
              git --version
            '';

            # Add devenv-up and devenv-test as scripts if needed
            scripts = {
              "devenv-up".exec = "echo devenv-up executed";
              "devenv-test".exec = "echo devenv-test executed";
            };
          }
        ];
      };
    };
}
