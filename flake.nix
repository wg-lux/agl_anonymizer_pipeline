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
      overlays = [
        (final: prev: {

          mupdf = prev.mupdf.overrideAttrs (old: {
            dontStrip = false;
            nativeBuildInputs = old.nativeBuildInputs or [] ++ [
              final.pkg-config
              final.libclang
            ];
            buildInputs = old.buildInputs or [] ++ [
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
              # Add tesseract if needed
              prev.tesseract
            ];
            makeFlags = old.makeFlags or [];  # Preserve existing makeFlags
          });

          pymupdf = prev.python311Packages.pymupdf.overrideAttrs (old: {
            dontStrip = false;
            nativeBuildInputs = old.nativeBuildInputs or [] ++ [
              final.mupdf
              final.pkg-config
              final.libclang
            ];
            postInstall = ''
              echo "Linking mupdf libraries"
              export LD_LIBRARY_PATH="${final.mupdf}/lib:$LD_LIBRARY_PATH"
              find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.mupdf}/lib {} \;
            '';
          });

          tokenizers = prev.python311Packages.tokenizers.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs or [] ++ [
              final.cargo
              final.rustc
              final.libclang
            ];
            postInstall = ''
              echo "Linking tokenizers libraries"
              export LD_LIBRARY_PATH="${final.cudatoolkit}/lib:$LD_LIBRARY_PATH"
              find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.cudatoolkit}/lib {} \;
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

    direnv = pkgs.direnv;  # Include direnv for environment management

    # Define the C++ toolchain with Clang and GCC
    clangVersion = "16";   # Version of Clang
    gccVersion = "13";     # Version of GCC
    llvmPkgs = pkgs."llvmPackages_${clangVersion}";  # LLVM toolchain
    gccPkg = pkgs."gcc${gccVersion}";  # GCC package for compiling

    # Create a clang toolchain with libstdc++ from GCC
    clangStdEnv = pkgs.stdenvAdapters.overrideCC llvmPkgs.stdenv (llvmPkgs.clang.override {
      gccForLibs = gccPkg;  # Link Clang with libstdc++ from GCC
    });
    



    lib = pkgs.lib;
    poetry2nixProcessed = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

    p2n-overrides = poetry2nixProcessed.defaultPoetryOverrides.extend (final: prev:
      builtins.mapAttrs (package: build-requirements:
        if package == "tokenizers" then
          prev.rustc.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs or [] ++ [
              final.cargo
              final.rustc
              final.libclang
            ];
          })

        else
          (builtins.getAttr package prev).overridePythonAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ (
              builtins.map (pkg:
                if builtins.isString pkg then builtins.getAttr pkg prev else pkg
              ) build-requirements
            );
          })
      )
    );


    # Poetry application setup
    poetryApp = poetry2nixProcessed.mkPoetryApplication {
      python = pkgs.python311;
      projectDir = ./.;  # Points to the project directory
      src = lib.cleanSource ./.;  # Clean the source code
      overrides = p2n-overrides;  # Apply package overrides for special requirements


      # Native build inputs for dependencies (e.g., C++ dependencies)
      nativeBuildInputs = with pkgs; [
        cudaPackages.saxpy
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
        python311Packages.pip
        gccPkg.libc
        cargo
        rustc
        mupdf
        pymupdf   
        python311Packages.hatchling
        maturin
        python311Packages.safetensors

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
      preShellHook = ''
        export LD_LIBRARY_PATH="${pkgs.cudatoolkit.lib}:${pkgs.cudnn.lib}:$LD_LIBRARY_PATH"

      '';  # Set the LD_LIBRARY_PATH for CUDA libraries

      inputsFrom = [ self.packages.x86_64-linux.poetryApp ];  # Include poetryApp in the dev environment
      packages = [ pkgs.poetry ];  # Install poetry in the devShell for development
      nativeBuildInputs = [ 
        pkgs.python311Packages.hatchling
        pkgs.maturin
        pkgs.python311Packages.safetensors
        pkgs.cargo
        pkgs.rustc
        pkgs.libclang
       ];  # CUDA toolkit version for devShell
      postShellHook =  ''

        poetry install  # Install the poetry application in the devShell
      '';
    };
  };
}