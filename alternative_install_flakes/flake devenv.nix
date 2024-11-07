{
  description = "Flake for the agl_anonymizer_pipeline service with CUDA support";

  # Define binary caches and trust settings
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    devenv.url = "github:cachix/devenv/9b6566c51efa2fdd6c6e6053308bc3a1c6817d31";
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.cudaSupport = true;
      };
    in {
      devShells.${system}.default = devenv.lib.mkShell {
        inherit pkgs;
        name = "agl_anonymizer_pipeline";

        # Primary build inputs, devenv first
        buildInputs = with pkgs; [
          devenv          
          python311
          git
          libcxx
          cudatoolkit
          cudnn
          python311Packages.numpy
          python311Packages.transformers
          python311Packages.torch
          python311Packages.torchvision
          python311Packages.torchaudio
          python311Packages.spacy
          python311Packages.spacy-lookups-data
          python311Packages.opencv4
          tesseract
          python311Packages.pymupdf
        ];

        # devenv-specific configuration and environment variables
        env = {
          GREET = "devenv";
          PROJECT_DIR = "${toString ./agl_anonymizer_pipeline}";
          CUDA_PATH = "${pkgs.cudatoolkit}";
          LD_LIBRARY_PATH = "${pkgs.cudatoolkit.lib}:${pkgs.cudnn.lib}:$LD_LIBRARY_PATH";
        };

        # Initialize devenv and CUDA environment
        shellHook = ''
          echo "Entering shell for $PROJECT_DIR with devenv and CUDA enabled"
          git --version
          python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
        '';

        # Custom scripts using devenv functionality
        scripts = {
          "devenv-up".exec = "echo devenv-up executed";
          "devenv-test".exec = "echo devenv-test executed";
        };
      };
    };
}
