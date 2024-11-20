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
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs"; # Ensure poetry2nix follows nixpkgs for consistency
    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk.url = "github:nix-community/naersk";


  };

  outputs = inputs@{ self, flake-utils, nixpkgs, poetry2nix, cachix, naersk, ... }:
      let
      system = "x86_64-linux"; # Define the system architecture
      pks = import nixpkgs { inherit system; };  # Import Nix packages
      naersk' = pkgs.callPackage naersk {};



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


      pkgs = import nixpkgs {

          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;  # Enable CUDA support in the configuration
            allowBroken = true;  # Allow broken packages for development
          };

          # Overlays are added to ensure the correct order of installation is used.
          # On Install some dependencies might not find a package that is needed for 
          # the build.
          # Without the overlay, the package may not be installed in the correct order.
          # This can lead to build failures.

          # Examples are the missing setup of a rust dependency like maturin
          # or of a c compiler.


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
                  prev.libjpeg

                  # Add tesseract if needed
                  prev.tesseract
                ];
                makeFlags = old.makeFlags or [];  # Preserve existing makeFlags
              });

              pymupdf = prev.python311Packages.pymupdf.overrideAttrs (old: {
                dontStrip = false;
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  prev.mupdf
                  prev.pkg-config
                  prev.libclang
                ];
                postInstall = ''
                  echo "Linking mupdf libraries"
                  export LD_LIBRARY_PATH="${final.mupdf}/lib:$LD_LIBRARY_PATH"
                  find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.mupdf}/lib {} \;
                '';
              });

              hatchling = prev.python311Packages.hatchling.overrideAttrs (old: {
                dontStrip = false;
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.python311
                  final.python311Packages.gdown
                ];
              });

              tokenizers = prev.python311Packages.tokenizers.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.hatchling
                  pkgs.python311Packages.setuptools
                ];
                postInstall = ''
                  echo "Linking tokenizers libraries"
                  export LD_LIBRARY_PATH="${final.cudaPackages.cudatoolkit}/lib:$LD_LIBRARY_PATH"
                  find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.cudaPackages.cudatoolkit}/lib {} \;
                '';
              });

              ftfy = prev.python311Packages.ftfy.overrideAttrs (old: {
                dontStrip = false;
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.python311
                  final.hatchling
                ];
              });

              triton = prev.python311Packages.openai-triton-cuda.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.cudaPackages.cudatoolkit
                  final.cudaPackages.cudnn
                ];
                buildPhase = ''
                  export CUDA_HOME=${final.cudaPackages.cudatoolkit}
                  export PATH=${final.cudaPackages.cudatoolkit}/bin/ptxas:$PATH
                  ${old.buildPhase or ""}
                '';
                postInstall = ''
                  echo "Linking Triton CUDA libraries"
                  export LD_LIBRARY_PATH=${final.cudaPackages.cudatoolkit}/lib64:$LD_LIBRARY_PATH
                  find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.cudaPackages.cudatoolkit}/lib64 {} \;
                '';
              });


            })
          ];

        };  
        lib = pkgs.lib;     



        poetry2nixProcessed = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };


        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication defaultPoetryOverrides;
        
        poetryApp = mkPoetryApplication {
            python = pkgs.python311;
            projectDir = ./.;  # Points to the project directory
            preferWheels = false;  # Disable wheel preference

            overrides = defaultPoetryOverrides.extend
            (final: prev: 
              {
              rustPkgs = naersk'.buildPackage {
                    src = ./rust;
              };

              gender-guesser = prev.gender-guesser.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              pptree = prev.pptree.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              conllu = prev.conllu.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              janome = prev.janome.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              wikipedia-api = prev.wikipedia-api.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              sentencepiece = prev.sentencepiece.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              segtok = prev.segtok.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  prev.setuptools
                ];
              });
              gdown = prev.gdown.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.hatch-fancy-pypi-readme
                ];
              });
              mpld3 = prev.mpld3.overridePythonAttrs (old: {
                buildInputs = old.buildInputs or [] ++ [
                  final.setuptools
                ];
              });
              flair = prev.flair.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                  final.flit
                  final.torch-bin
                  final.triton
                ];

                buildInputs = old.buildInputs or [] ++ [
                  final.rustPkgs
                  prev.hatch-fancy-pypi-readme
                ];
              });
              safetensors = prev.safetensors.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools-rust
                  final.rustPkgs
                ];
              });
              tokenizers = prev.tokenizers.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.rustPkgs
                  final.setuptools-rust
                ];
              });
              transformers = prev.transformers.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.rustPkgs
                  final.setuptools-rust
                ];

              });
              pytorch-revgrad = prev.pytorch-revgrad.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.flit
                ];
              });
              maturin = prev.maturin.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools-rust
                  final.rustPkgs
                ];
              });
              confection = prev.confection.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                ];
              });
              miniful = prev.miniful.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                ];
              });
              fst-pso = prev.fst-pso.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                ];
              });
              fuzzytm = prev.fuzzytm.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                ];
              });
              gensim = prev.gensim.overridePythonAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.setuptools
                  final.wheel
                  final.cython
                  final.stdenv.cc.cc
                ];
                buildInputs = old.buildInputs or [] ++ [
                  final.numpy
                ];
              });


            PIP_NO_CACHE_DIR = "off";


            # Native build inputs for dependencies (e.g., C++ dependencies)
            nativeBuildInputs = with pkgs; [
              python311
              python311Packages.build
              python311Packages.setuptools-rust
              rustPkgs
              cudaPackages.saxpy
              cudaPackages.cudatoolkit
              cudaPackages.cudnn
              mupdf
              pymupdf
              stdenv
              hatchling
              python311Packages.hatch-fancy-pypi-readme
              python311Packages.flit
              ftfy
              ];

          buildInputs = with pkgs.python311Packages; [
            # Runtime dependencies
            cython
            pip
            build
            gdown
            ftfy
            sympy
            tokenizers
            tomlkit
            cudaPackages.cudaPackages.cudatoolkit
            torch-bin
            torchvision-bin
            torchaudio-bin
            coreutils-full
            python311Packages.flit
          ];

          
        });

        };
        

        in
        {
        # Configuration for Nix binary caches and CUDA support
        packages.${system}.default = poetryApp;
        environment.systemPackages = with pkgs; [cudaPackages.cudatoolkit];
        hardware.graphics.enable = true;
        boot.kernelPackages = pkgs.linuxPackages_latest;
        boot.kernelParams = [ 
          "nvidia-drm.modeset=1"
          "nvidia-drm.fbdev=1"
        ];
        hardware.nvidia = {
          powerManagement = {
            enable = true;
            finegrained = false;
          };
          nvidiaSettings = true;
        };

        nixConfig = {
          binary-caches = [
            nvidiaCache.binaryCachePublicUrl
          ];
          binary-cache-public-keys = [
            nvidiaCache.publicKey
          ];
          cudaSupport = true;  # Enable CUDA support in the Nix environment
          programs.nix-ld.enable = true;  # Enable the nix-ld program
        };
        configureFlags = [

          "--prefix=$out"
          "--localstatedir=$NIX_BUILD_TOP" # Redirect state files to tmp directory
        ];

        mkShell = {
          buildInputs = with pkgs; [
            git gitRepo gnupg autoconf curl
            procps gnumake util-linux m4 gperf unzip
            cudaPackages.cudatoolkit linuxPackages.nvidia_x11
            libGLU libGL
            xorg.libXi xorg.libXmu freeglut
            xorg.libXext xorg.libX11 xorg.libXv xorg.libXrandr zlib 
            ncurses5 stdenv.cc binutils
          ];
          shellHook = ''
            export NIX_CCFLAGS="-/usr/include"
            export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
            # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
            export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
            export EXTRA_CCFLAGS="-I/usr/include"
          ''; 

          NIX_LD = lib.fileContents "${pkgs.cudaPackages.cudatoolkit}/nix-support/dynamic-linker";
          apps.agl_anonymizer_pipeline = {
            buildPhase = ''
              maturin build --release -m pyproject.toml
              export RUSTFLAGS="-C link-arg=-L${pkgs.cudaPackages.cudatoolkit}/lib64 -C link-arg=-lcudart -C link-arg=-lcudnn"
              rustup target add x86_64-linux
              
            '';
            type = "app";
            program = "${poetryApp}/bin/agl_anonymizer_pipeline";
          };
        };

    };

      
}