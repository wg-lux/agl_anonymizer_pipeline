{
  description = "Flake for the agl_anonymizer_pipeline service with CUDA support";

  # Configuration for binary caches and keys
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    
    # Add these important settings
    substitute = true;  # Enable substitution
    trust-substituters = true;  # Trust binary caches
    builders-use-substitutes = true;  # Allow builders to use substitutes
    extra-sandbox-paths = [
      "/usr/lib64/"
    ];
    sandbox = false;  # Disable the sandbox for building
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
      pks = import nixpkgs { inherit system; 
        overlays = [
          (final: prev: {
              # Replace the custom LLVM build with pre-built packages
              customLLVM = final.llvmPackages_12.libllvm.override {
                buildLlvmTools = old: old // {
                  cmakeFlags = (old.cmakeFlags or []) ++ [
                    "-DLLVM_TARGETS_TO_BUILD=X86"
                    "-DCMAKE_BUILD_TYPE=Release"
                    "-DLLVM_OPTIMIZED_TABLEGEN=ON"
                  ];
                };
              };
              # Then create an overlay for the libraries
              llvmLibs = final.stdenv.mkDerivation {
                name = "llvm-libs";
                buildCommand = ''
                  mkdir -p $out/lib
                  ln -s ${final.llvmPackages_12.libclang}/lib/libclang.so* $out/lib/
                  ln -s ${final.llvmPackages_12.libllvm}/lib/libLLVM*.so* $out/lib/
                '';
              };

              # Create a wrapper script to set environment variables
              llvmWrapper = final.writeScriptBin "llvm-wrapper" ''
                export LD_LIBRARY_PATH="${final.llvmPackages_12.libclang}/lib:${final.llvmPackages_12.libllvm}/lib:$LD_LIBRARY_PATH"
                export LIBCLANG_PATH="${final.llvmPackages_12.libclang}/lib"
                export LLVM_SYS_120_PREFIX="${final.llvmPackages_12.libllvm}"
                export LLVM_CONFIG_PATH="${final.llvmPackages_12.llvm}/bin/llvm-config"
                exec "$@"
              '';

          })
        ];
        };  # Import Nix packages
      naersk' = pkgs.callPackage naersk {
        inherit (pkgs) cargo rustc;
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
      llvmPkgs = pkgs."llvmPackages_12_${clangVersion}";  # LLVM toolchain
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

          # naersk is used to compile rust packages with the version of maturin
          # this uses the rust packages specified in cargo.lock, generated by running cargo 
          # update inside the rust folder


          overlays = [
            (final: prev: {
              cython = prev.python311Packages.cython.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.python311
                  final.hatchling
                ];
              });
              wheel = prev.python311Packages.wheel.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.python311
                  final.hatchling
                ];
              });
              blas = prev.blas.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.stdenv.cc.cc
                  final.clang
                ];
              });

              mupdf = prev.mupdf.overrideAttrs (old: {
                dontStrip = false;
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.pkg-config
                  final.libclang
                  final.blas
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

              triton = prev.triton.overrideAttrs (old: {
                format = "wheel";
                sandbox = false;
                preferWheel = true;
                
                # Use specific version known to work with PyTorch
                version = "2.1.0";  # or another stable version
                
                propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
                  final.cudaPackages.cudatoolkit
                  final.cudaPackages.cuda_nvcc
                  final.linuxPackages.nvidia_x11
                  final.cudaPackages.cudnn
                  final.cudaPackages.saxpy
                  final.libllvm
                ];

                # Skip build phases since we're using wheel
                dontInstall = false;

                # Set environment variables
                postFixup = ''
                  mkdir -p $out/lib/python3.11/site-packages/triton/backends/nvidia/bin/
                  ln -s ${final.cudaPackages.cuda_nvcc}/bin/ptxas $out/lib/python3.11/site-packages/triton/backends/nvidia/bin/ptxas
                '';
              });
              torch = prev.torch-bin.overridePythonAttrs (old: {
                format = "wheel";
                preferWheel = true;
                sandbox = false;
                buildInputs = (old.buildInputs or []) ++ [
                  final.python311Packages.setuptools
                  final.python311Packages.wheel
                  final.python311Packages.cython
                  final.stdenv.cc.cc
                ];
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
            preferWheels = true;  # Disable wheel preference
            nativeBuildInputs = with pkgs; [
              cudaPackages.cuda_nvcc
              cudaPackages.cudatoolkit
              python311Packages.setuptools
              linuxPackages.nvidia_x11
              llvmPackages_12.clang
              clang
              llvmPackages_12.libllvm
              rustc
              cargo
            ];
            buildInputs = with pkgs; [
              cudaPackages.cuda_nvcc
              cudaPackages.cudatoolkit
            ];

            
            # For the rust build
            RUST_BACKTRACE = "1";
            RUSTFLAGS = "-C target-cpu=native";


            overrides = defaultPoetryOverrides.extend
            (final: prev: 
              {

              llvmPackages_12 = prev.llvmPackages_12; 
              libllvm = final.llvmPackages_12.libllvm.override {
                enableShared = true;
              };

              rustPkgs = naersk'.buildPackage {
                override = {
                  rustc = pkgs.rustc;
                  cargo = pkgs.cargo;
                };
                src = ./rust;
                nativeBuildInputs = with pkgs; [
                  llvmPackages_12.libclang
                  pkg-config
                  cmake
                  rustc
                  cargo
                ];
                buildInputs = with pkgs; [
                  llvmPackages_12.libllvm
                  llvmPackages_12.libclang
                ];
                copyLibs = true;
                
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
              torch = prev.torch;  # Use pre-built torch
    
              flair = prev.flair.overridePythonAttrs (old: {
                format = "wheel";
                preferWheel = true;
                nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                  final.rustPkgs
                  final.cmake
                  final.libclang
                  final.pkgconfig
                  final.setuptools
                  final.maturin
                ];
                buildInputs = (old.buildInputs or []) ++ [
                  final.torch
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
                  final.cmake

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

                # ... your other overlays ...
              agl_anonymizer_pipeline-deps = prev.agl_anonymizer_pipeline-deps.overridePythonAttrs (old: {
              nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                prev.llvmWrapper
                prev.llvmLibs
                final.llvmPackages_12.libllvm
                final.llvmPackages_12.libclang
                final.clang
                final.llvmPackages_12.clang-unwrapped
                final.pkg-config
                final.setuptools
                final.maturin
                final.cudatoolkit
                final.cmake
              ];
              buildInputs = old.buildInputs or [] ++ [
                final.llvmLibs
                final.llvmPackages_12.libclang
              ];
              
              LIBCLANG_PATH = "${final.llvmPackages_12.libclang}/lib";
              LLVM_SYS_120_PREFIX = "${final.llvmPackages_12.libllvm}";
              LLVM_CONFIG_PATH = "${final.llvmPackages_12.libllvm}/bin/llvm-config";
              
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
          stdenv.cc.cc
          python311Packages.wheel
          python311Packages.cython
          blas
          python311Packages.cmake
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
          cudaPackages.cudatoolkit
          torch-bin
          torchvision-bin
          torchaudio-bin
          coreutils-full
          python311Packages.flit
        ]; 
      });
        
      };

      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          cudaPackages.cudatoolkit
          linuxPackages.nvidia_x11
          libGLU
          libGL
          xorg.libXi
          xorg.libXmu
          freeglut
          pkg-config
        ];

      };
      

      in
      {
      # Configuration for Nix binary caches and CUDA support
      packages.${system}.default = poetryApp;

      devShells.${system}.default = devShell;

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
}