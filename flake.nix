{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    devenv.url = "github:cachix/devenv";
    
    # Add uv2nix and its dependencies
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
outputs = { self, nixpkgs, devenv, pyproject-nix, uv2nix, pyproject-build-systems, ... } @ inputs:
let
  system = "x86_64-linux";

  # Fix pkgs configuration
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      autoAddDriverRunpath = true;
    };

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

          cuda_nvcc = prev.cudaPackages.cuda_nvcc.overrideAttrs (old: {
            buildPhase = (old.preBuild or "") + ''
              export CXX=${final.gcc10}/bin/g++

              '';

            buildInputs = (old.buildInputs or []) ++ [
              final.stdenv.cc.cc
              final.gcc10

            ];

          });
          nccl = prev.cudaPackages.nccl.overrideAttrs (old: {
            buildPhase = (old.buildPhase or "") + ''
              export CXX=${final.gcc10}/bin/g++

              '';

            buildInputs = (old.buildInputs or []) ++ [
              final.stdenv.cc.cc
              final.cudaPackages.cuda_nvcc
              final.gcc10


            ];

          });
          cudatoolkit = prev.cudaPackages.cudatoolkit.overrideAttrs (old: {
            buildPhase = (old.preBuild or "") + ''
              export CXX=${final.gcc10}/bin/g++

              '';

            buildInputs = (old.buildInputs or []) ++ [
              final.stdenv.cc.cc
              final.gcc10
              final.cuda_nvcc
              final.nccl

            ];

          });
          cudnn = prev.cudaPackages.cudnn.overrideAttrs (old: {
            buildPhase = (old.preBuild or "") + ''
              export CXX=${final.gcc10}/bin/g++

              '';

            buildInputs = (old.buildInputs or []) ++ [
              final.stdenv.cc.cc
              final.gcc10
              final.cuda_nvcc
              final.nccl
              final.cudatoolkit

            ];

          });

          nvidia_x11 = prev.linuxPackages.nvidia_x11.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [
              final.cudatoolkit
              final.cuda_nvcc
              final.gcc10
              final.nccl
              final.cudnn
              final.libllvm
            ];
            buildPhase = ''
              export CXX=${final.gcc10}/bin/g++
              '';
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
          torch = prev.python311Packages.torch-bin.overridePythonAttrs (old: {
            format = "wheel";
            preferWheel = true;
            sandbox = false;
            buildInputs = (old.buildInputs or []) ++ [
              final.python311Packages.setuptools
              final.python311Packages.wheel
              final.python311Packages.cython
              final.stdenv.cc.cc
              final.gcc10
              final.cudatoolkit
              final.cudnn
              final.nccl
              final.cuda_nvcc
              final.triton
            ];
            buildPhase = ''
              export CXX=${final.gcc10}/bin/g++
            '';

          });
          torchvision = prev.python311Packages.torchvision-bin.overridePythonAttrs (old: {
            format = "wheel";
            preferWheel = true;
            sandbox = false;
            buildInputs = (old.buildInputs or []) ++ [
              final.python311Packages.setuptools
              final.python311Packages.wheel
              final.python311Packages.cython
              final.stdenv.cc.cc
            ];
            buildPhase = ''
              export CXX=${final.gcc10}/bin/g++
              '';

          });

      })
    ];

  };
  inherit (nixpkgs) lib;  
  # Add uv2nix workspace setup
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };


  python = pkgs.python311;



  pythonSet = 
  (pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
    ]
  );
in {
  packages.x86_64-linux.default = pythonSet.mkVirtualEnv "agl_anonymizer_pipeline-env" workspace.deps.default;
    impure = pkgs.mkShell {
    packages = with pkgs; [
      python
      uv
      # Add OpenGL and related libraries
      libGL
      libGLU
      xorg.libX11
      mesa
      # System libraries needed by OpenCV
      stdenv.cc.cc.lib
      zlib
      glib
      tesseract


    ];
    buildPhase = ''
      export TMPDIR=$(mktemp -d)
    '';
    
    shellHook = ''
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.libGL
        pkgs.libGLU
        pkgs.xorg.libX11
        pkgs.mesa
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.glib
        pkgs.tesseract

      ]}:$LD_LIBRARY_PATH
            unset PYTHONPATH
      export UV_PYTHON_DOWNLOADS=never
      
      # Create and activate venv if it doesn't exist
      if [ ! -d .venv ]; then
        uv venv .venv
      fi
      source .venv/bin/activate
      cd agl_anonymizer_pipeline
      python -m spacy download de_core_news_md
      mkdir ./agl-anonymizer-temp
      mkdir ./agl-anonymizer

    '';
  };
  cuda = pkgs.mkShell {

    packages = with pkgs; [
      python
      uv
      # Add OpenGL and related libraries
      libGL
      libGLU
      xorg.libX11
      mesa
      # System libraries needed by OpenCV
      stdenv.cc.cc.lib
      zlib
      glib
      gcc10

      tesseract
      cuda_nvcc
      nccl
      cudatoolkit
      
      cudnn
      nvidia_x11
      torch
      torchvision
      triton
      python311Packages.setuptools
      python311Packages.wheel
      python311Packages.cython

    ];
    
    shellHook = ''
      export NVIDIA_DRIVER_PATH="${pkgs.linuxPackages.nvidia_x11}/lib"
      export NVIDIA_NVML_PATH="${pkgs.linuxPackages.nvidia_x11}/lib"
      export NVML_LIBRARY_PATH="${pkgs.linuxPackages.nvidia_x11}/lib/libnvidia-ml.so"


      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.libGL
        pkgs.libGLU
        pkgs.xorg.libX11
        pkgs.mesa
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.glib
        pkgs.tesseract
        pkgs.python311Packages.setuptools
        pkgs.python311Packages.wheel
        pkgs.python311Packages.cython
        pkgs.gcc10

        pkgs.cudaPackages.cuda_nvcc
        pkgs.cudaPackages.cudatoolkit
        pkgs.cudaPackages.nccl
        pkgs.cudaPackages.cudnn
        pkgs.linuxPackages.nvidia_x11
        pkgs.python311Packages.pynvml
        pkgs.python311Packages.torch-bin
        pkgs.python311Packages.torchvision-bin

      ]}:$LD_LIBRARY_PATH
            unset PYTHONPATH
      export UV_PYTHON_DOWNLOADS=never
      
      # Create and activate venv if it doesn't exist
      if [ ! -d .venv ]; then
        uv venv .venv
      fi
      source .venv/bin/activate
      export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
      # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
      export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
      export EXTRA_CCFLAGS="-I/usr/include"
      export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit}/lib64:$LD_LIBRARY_PATH
      export EXTRA_LDFLAGS="-L${pkgs.cudaPackages.cudatoolkit}/lib64"
      export EXTRA_CCFLAGS="-I${pkgs.cudaPackages.cudatoolkit}/include"
      export PATH=${pkgs.cudaPackages.cudatoolkit}/bin:$PATH
      export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
      export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"
      export CUDA_ROOT="${pkgs.cudaPackages.cudatoolkit}"
      export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.python311Packages.pynvml}/lib:$LD_LIBRARY_PATH"
      export XLA_FLAGS="--xla_gpu_cuda_data_dir=${pkgs.cudaPackages.cudatoolkit}"
      export EXTRA_LDFLAGS="-L/lib -L${pkgs.cudaPackages.cudatoolkit}/lib"
      export EXTRA_CCFLAGS="-I/usr/include"
      export CUDA_TOOLKIT_ROOT_DIR="${pkgs.cudaPackages.cudatoolkit}"
      export CUDA_TOOLKIT_ROOT="${pkgs.cudaPackages.cudatoolkit}"
      export CUDNN_ROOT="${pkgs.cudaPackages.cudnn}"
    
      cd agl_anonymizer_pipeline
      python -m spacy download de_core_news_md
      mkdir ./agl-anonymizer-temp
      mkdir ./agl-anonymizer
      echo "Testing CUDA availability..."
      python -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('CUDA device count:', torch.cuda.device_count()); print('CUDA version:', torch.version.cuda)"

    '';
  };


  uv2nix =
    let
      # Create an overlay enabling editable mode for all local dependencies.
      editableOverlay = workspace.mkEditablePyprojectOverlay {
        # Use environment variable
        root = "$REPO_ROOT";
        # Optional: Only enable editable for these packages
        # members = [ "hello-world" ];
      };

      # Override previous set with our overrideable overlay.
      editablePythonSet = pythonSet.overrideScope editableOverlay;

      # Build virtual environment, with local packages being editable.
      #
      # Enable all optional dependencies for development.
      virtualenv = editablePythonSet.mkVirtualEnv "agl_anonymizer_pipeline-env" workspace.deps.all;

    in
  pkgs.mkShell {
    packages = [
      virtualenv
      pkgs.uv
    ];
    env = {
      # Add uv2nix to PATH
      PATH = "${pkgs.uv}/bin:$PATH";
      LD_LIBRARY_PATH = "${lib.makeLibraryPath}:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
      TESSDATA_PREFIX = "${pkgs.tesseract}/share/tessdata";  # Add this line
      CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
      CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

    };
    shellHook = ''
      # Undo dependency propagation by nixpkgs.
      unset PYTHONPATH

      # Don't create venv using uv
      export UV_NO_SYNC=1

      # Prevent uv from downloading managed Python's
      export UV_PYTHON_DOWNLOADS=never

      # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
      export REPO_ROOT=$(git rev-parse --show-toplevel)
    '';
  };
};
}
