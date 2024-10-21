{
  description = "Flake for the agl_anonymizer_pipeline service with CUDA support";

  # Configuration for binary caches and keys
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
    extra-substituters = "https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org";
    extra-trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=";
  };

  # Inputs: Define where Nix packages, poetry2nix, and cachix are sourced
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs"; # Ensure poetry2nix follows nixpkgs for consistency
    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Outputs: Define the packages, devShell, and configurations
  outputs = { self, nixpkgs, poetry2nix, cachix }:  
  let
    system = "x86_64-linux";  # Define the system architecture
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        cudaSupport = true;  # Enable CUDA support in the configuration
        allowBroken = true;  # Allow broken packages for development
      };
      # Overriding the mupdf package and the pymupdf build to include necessary clang environment in the build.
      overlays = [
        (final: prev: {
          mupdf = prev.mupdf.overrideAttrs (oldAttrs: {
            nativeBuildInputs = oldAttrs.nativeBuildInputs or [] ++ [
              final.pkg-config
              final.libclang
              final.stdenv
            ];
            makeFlags = [ "CC=${pkgs.stdenv.cc.targetPrefix}cc" "CC=${pkgs.clang}" "CXX=${pkgs.cxxopts}" ];  # Set the C++ compiler to Clang

            buildInputs = oldAttrs.buildInputs or [] ++ [
              # Include necessary dependencies
              prev.autoPatchelfHook
              prev.openjpeg
              prev.jbig2dec
              prev.freetype
              prev.harfbuzz
              prev.gumbo
              prev.freeglut
              prev.libGLU
              prev.libjpeg_turbo
              prev.tesseract
            ];
          });

          pymupdf = prev.python311Packages.pymupdf.overrideAttrs (old: {

            nativeBuildInputs = old.nativeBuildInputs or [] ++ [
              final.mupdf
              final.pkg-config
              final.libclang
              final.stdenv
            ];
            postInstall = ''
              echo "Linking mupdf libraries"
              export LD_LIBRARY_PATH="${final.mupdf}/lib:$LD_LIBRARY_PATH"
              find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.mupdf}/lib {} \;
            '';
          });
        })
      ];
    };

    # Use cachix to cache NVIDIA-related packages
    nvidiaCache = cachix.lib.mkCachixCache {
      inherit (pkgs) lib;
      name = "nvidia";
      publicKey = "nvidia.cachix.org-1:dSyZxI8geDCJrwgvBfPH3zHMC+PO6y/BT7O6zLBOv0w=";
      secretKey = null;  # Not needed for pulling from the cache
    };

    # Define the C++ toolchain with Clang and GCC
    clangVersion = "16";   # Version of Clang
    gccVersion = "13";     # Version of GCC
    llvmPkgs = pkgs."llvmPackages_${clangVersion}";  # LLVM toolchain
    gccPkg = pkgs."gcc${gccVersion}";  # GCC package for compiling

    # Create a clang toolchain with libstdc++ from GCC
    clangStdEnv = pkgs.stdenvAdapters.overrideCC llvmPkgs.stdenv (llvmPkgs.clang.override {
      gccForLibs = gccPkg;  # Link Clang with libstdc++ from GCC
    });

    # Poetry to Nix package translation with specific build requirements
    pypkgs-build-requirements = {
      gender-guesser = [ "setuptools" ];
      conllu = [ "setuptools" ];
      janome = [ "setuptools" ];
      pptree = [ "setuptools" ];
      wikipedia-api = [ "setuptools" ];
      django-flat-theme = [ "setuptools" ];
      django-flat-responsive = [ "setuptools" ];
    };

    lib = pkgs.lib;
    poetry2nixProcessed = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

    p2n-overrides = poetry2nixProcessed.defaultPoetryOverrides.extend (final: prev:
      builtins.mapAttrs (package: build-requirements:
        (builtins.getAttr package prev).overridePythonAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ (
            builtins.map (pkg:
              if builtins.isString pkg then builtins.getAttr pkg prev else pkg
            ) build-requirements
          );
        })
      ) 
      pypkgs-build-requirements

    );

    # Poetry application setup
    poetryApp = poetry2nixProcessed.mkPoetryApplication {
      python = pkgs.python311;
      projectDir = ./.;  # Points to the project directory
      src = lib.cleanSource ./.;  # Clean the source code
      overrides = p2n-overrides;  # Apply package overrides for special requirements
      preferWheels = true;  # Prefer binary wheels for performance

      # Native build inputs for dependencies (e.g., C++ dependencies)
      nativeBuildInputs = with pkgs; [
        gcc
        llvmPkgs.clang
        python311Packages.pip
        python311Packages.setuptools
        python311Packages.torch-bin
        python311Packages.torchvision-bin
        python311Packages.torchaudio-bin
        gccPkg.libc
        mupdf
        python311Packages.pymupdf  
        python311Packages.tokenizers
      ];
      };


  in {
    # Configuration for Nix binary caches and CUDA support
    nixConfig = {
      binary-caches = [
        nvidiaCache.binaryCachePublicUrl
      ];
      binary-cache-public-keys = [
        nvidiaCache.publicKey
      ];
      cudaSupport = true;  # Enable CUDA support in the Nix environment
    };

    # Package definition for building the poetry application
    packages.x86_64-linux.poetryApp = poetryApp;

    # Default package points to the poetry application
    packages.x86_64-linux.default = poetryApp;

    # Development shell for setting up the environment
    devShells.x86_64-linux.default = pkgs.mkShell {
      inputsFrom = [ self.packages.x86_64-linux.poetryApp ];  # Include poetryApp in the dev environment
      packages = [ pkgs.poetry  ];  # Install poetry in the devShell for development
      nativeBuildInputs = [ pkgs.cudaPackages_11.cudatoolkit ];  # CUDA toolkit version for devShell

      
      shellHook = ''
        # Set LD_LIBRARY_PATH to include Nix-provided libraries
        export LD_LIBRARY_PATH="${gccPkg.libc}/lib:${pkgs.mupdf}/lib:${pkgs.python311Packages.pymupdf}/lib:$LD_LIBRARY_PATH"

        # Set PYTHONPATH to include Nix-provided Python libraries
        export PYTHONPATH="${pkgs.python311Packages.tokenizers}/lib/python3.11/site-packages:${pkgs.python311Packages.torch}/lib/python3.11/site-packages:${pkgs.python311Packages.torchvision}/lib/python3.11/site-packages:${pkgs.python311Packages.torchaudio}/lib/python3.11/site-packages:$PYTHONPATH"
      '';
    };

  };
}
