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

  # Inputs: Define where Nix packages and mach-nix are sourced
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mach-nix.url = "github:DavHau/mach-nix";
  };

  # Outputs: Define the packages, devShell, and configurations
  outputs = { self, nixpkgs, mach-nix }:  
  let
    system = "x86_64-linux";  # Define the system architecture

    # Custom overlays for mupdf and pymupdf
    overlays = [
      (final: prev: {
        mupdf = prev.mupdf.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
            final.pkg-config
            final.libclang
          ];
          buildInputs = (old.buildInputs or []) ++ [
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
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
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
      })
    ];

    pkgs = import nixpkgs {
      inherit system;
      overlays = overlays;
      config = {
        allowUnfree = true;
        cudaSupport = true;  # Enable CUDA support in the configuration
      };
    };

    # Import mach-nix by passing pkgs
    machNix = import mach-nix {
      inherit pkgs;
    };

    # Define the Python environment using machNix
    pythonEnv = machNix.mkPython {
      python = pkgs.python311;  # Specify Python version
      requirements = builtins.readFile ./requirements.txt;
      providers = {
        _default = "wheel,sdist,nixpkgs";  # Prefer wheels first for speed
      };
      packagesExtra = with pkgs.python311Packages; [
        pymupdf
        # Add other custom packages if necessary
      ];
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

  in {
    # Configuration for Nix binary caches and CUDA support
    nixConfig = {
      binary-caches = [
        "https://cuda-maintainers.cachix.org"
      ];
      binary-cache-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      cudaSupport = true;  # Enable CUDA support in the Nix environment
    };

    # Default package points to the mach nix application
    packages.${system}.default = pythonEnv;

    # Development shell for setting up the environment
    devShells.${system}.default = pkgs.mkShell {
      nativeBuildInputs = [ pkgs.cudaPackages_11.cudatoolkit ];  # CUDA toolkit version for devShell
      buildInputs = [ pythonEnv ];
      shellHook = ''
        echo "Setting up development environment"
        export LD_LIBRARY_PATH="${gccPkg.libc}/lib:$LD_LIBRARY_PATH"
      '';
    };
  };
}
