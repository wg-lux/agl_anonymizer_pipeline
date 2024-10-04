{
  description = "Flake for the `agl_anonymizer_pipeline` service with CUDA support";

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
      };
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
      ) pypkgs-build-requirements
    );


    # Fetch mupdf from GitHub and ensure it's built with shared libraries
    mupdf-shared = pkgs.fetchFromGitHub {
      owner = "ArtifexSoftware";
      repo = "mupdf";
      rev = "b382877";  # Example commit hash for mupdf version
      sha256 = "d7ff4e572669d9f6f604aab03c01df26d9c83e17ed3604e891f9242254e3a578";  # SHA256 hash of the tarball
    };

    # Build mupdf with shared libraries
    mupdf = pkgs.mupdf.overrideAttrs (old: {
      configureFlags = old.configureFlags or [] ++ [ "--enable-shared" ];
      NIX_CFLAGS_COMPILE = "${old.NIX_CFLAGS_COMPILE or ""} -fPIC";
    });

    # Poetry application setup
    poetryApp = poetry2nixProcessed.mkPoetryApplication {
      python = pkgs.python311;
      projectDir = ./.;  # Points to the project directory
      src = lib.cleanSource ./.;  # Clean the source code
      overrides = p2n-overrides;  # Apply package overrides for special requirements
      preferWheels = true;  # Prefer binary wheels for performance

      # Native build inputs for dependencies (e.g., C++ dependencies)
      nativeBuildInputs = with pkgs; [
        python311Packages.pip
        python311Packages.setuptools
        python311Packages.torch-bin
        python311Packages.torchvision-bin
        python311Packages.torchaudio-bin
        gccPkg.libc
        llvmPkgs.libstdcxxClang
        pkgs.opencv
        mupdf-headless
      ];

      # Install phase for linking mupdf libraries
      installPhase = ''
        echo "Linking mupdf libraries"
        export LDFLAGS="$LDFLAGS -L${mupdf}/lib -libmupdf -libmupdfcpp.so.24.9"
        export CFLAGS="$CFLAGS -I${mupdf}/include"
        export LD_LIBRARY_PATH="${gccPkg.libc}/lib:$LD_LIBRARY_PATH"  # Correct path for libstdc++.so.6
      '';
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
      packages = [ pkgs.poetry ];  # Install poetry in the devShell for development
      nativeBuildInputs = [ pkgs.cudaPackages_11.cudatoolkit ];  # CUDA toolkit version for devShell
      shellHook = ''
        print "Setting up development environment"
        export LD_LIBRARY_PATH="${gccPkg.libc}/lib:$LD_LIBRARY_PATH"
  '';
    };
  };
}
