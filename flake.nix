{
  description = "Flake for the Django-based `agl-anonymizer` service with CUDA and C++ support";

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

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, cachix, ... } @ inputs:
  let
    nvidiaCache = cachix.lib.mkCachixCache {
      inherit (pkgs) lib;
      name = "nvidia";
      publicKey = "nvidia.cachix.org-1:dSyZxI8geDCJrwgvBfPH3zHMC+PO6y/BT7O6zLBOv0w=";
      secretKey = null;
    };

    system = "x86_64-linux";
    self = inputs.self;

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
      };
    };

    # Define the C++ toolchain
    clangVersion = "16";
    gccVersion = "13";
    llvmPkgs = pkgs."llvmPackages_${clangVersion}";
    gccPkg = pkgs."gcc${gccVersion}";

    # Set up clang with libstdc++ from GCC
    clangStdEnv = pkgs.stdenvAdapters.overrideCC llvmPkgs.stdenv (llvmPkgs.clang.override {
      gccForLibs = gccPkg;
    });

    pypkgs-build-requirements = {
      gender-guesser = [ "setuptools" ];
      conllu = [ "setuptools" ];
      janome = [ "setuptools" ];
      pptree = [ "setuptools" ];
      wikipedia-api = [ "setuptools" ];
      django-flat-theme = [ "setuptools" ];
      django-flat-responsive = [ "setuptools" ];
    };

    poetry2nix = inputs.poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

    lib = pkgs.lib;

    # Define mupdf-shared
    mupdf-shared = pkgs.mupdf.overrideAttrs (oldAttrs: rec {
      enableSharedLibraries = true;
      NIX_CFLAGS_COMPILE = oldAttrs.NIX_CFLAGS_COMPILE or "" + " -fPIC";
    });

    # Adjust p2n-overrides to include pymupdf override
    p2n-overrides = poetry2nix.defaultPoetryOverrides.extend (final: prev:
      (builtins.mapAttrs (package: build-requirements:
        (builtins.getAttr package prev).overridePythonAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ (
            builtins.map (pkg:
              if builtins.isString pkg then builtins.getAttr pkg prev else pkg
            ) build-requirements
          );
        })
      ) pypkgs-build-requirements)
      // {
        pymupdf = prev.pymupdf.overridePythonAttrs (oldAttrs: rec {
          buildInputs = (oldAttrs.buildInputs or []) ++ [ mupdf-shared ];
        });
      }
    );

    poetryApp = poetry2nix.mkPoetryApplication {
      python = pkgs.python311;
      projectDir = ./.;
      src = lib.cleanSource ./.;
      overrides = p2n-overrides;
      preferWheels = true;
      propagatedBuildInputs =  with pkgs.python311Packages; [];
      nativeBuildInputs = with pkgs; [
        python311Packages.pip
        python311Packages.setuptools
        python311Packages.torch-bin
        python311Packages.torchvision-bin
        python311Packages.torchaudio-bin

        # C++ dependencies
        gccPkg.libc
        llvmPkgs.libstdcxxClang
        pkgs.opencv
        mupdf
      ];
    };

  in {
    nixConfig = {
      binary-caches = [
        nvidiaCache.binaryCachePublicUrl
      ];
      binary-cache-public-keys = [
        nvidiaCache.publicKey
      ];
      cudaSupport = true;
    };

    packages.x86_64-linux.poetryApp = poetryApp;
    packages.x86_64-linux.default = poetryApp;

    devShells.x86_64-linux.default = pkgs.mkShell.override {
      stdenv = clangStdEnv;
    } rec {
      nativeBuildInputs = [
        pkgs.python311Packages.poetry-core
        gccPkg.libc
        llvmPkgs.libstdcxxClang
        pkgs.opencv
        pkgs.mupdf
      ];

      shellHook = ''
        export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
        export CUDA_NVCC_FLAGS="--compiler-bindir=$(which gcc)"
        export PATH="${pkgs.cudaPackages.cudatoolkit}/bin:$PATH"
        export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ gccPkg.libc llvmPkgs.libstdcxxClang ]}"
      '';
    };
  };
}
