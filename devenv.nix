{ pkgs, lib, config, inputs, ... }:
let
  pythonVersion = "python311";
  python = pkgs.${pythonVersion};
  
  buildInputs = with pkgs; [
    python
    cudaPackages.cuda_cudart
    cudaPackages.cudnn
    cudaPackages.cuda_nvcc
    stdenv.cc.cc
    libcxx
    clang-tools
    libclang
    llvmPackages_12.libllvm
    llvmPackages_12.libclang
    pkg-config
    cmake
    mupdf
    rustc
    cargo
  ];

  pythonPackages = ps: with ps; [
    setuptools
    wheel
    pip
    numpy
    spacy
    spacy-lookups-data
    gender-guesser
    gensim
    pytesseract
    imutils
    opencv4
    pytorch-revgrad
    flair
    transformers
    pymupdf
    tokenizers
    hatchling
    ftfy
    safetensors
    torch-bin
    torchvision-bin
    torchaudio-bin
    gdown
  ];
in 
{
  packages = with pkgs; [
    git
    harfbuzz
    freetype
    autoPatchelfHook
    openjpeg
    jbig2dec
    gumbo
    freeglut
    libGLU
    libjpeg_turbo
    tesseract
    lcms2
    cudaPackages.cuda_nvcc
  ] ++ buildInputs;

  env = {
    PYTHON_VERSION = "3.11.9";
    PYTHONPATH = "${python}/lib/python3.11/site-packages:$PWD";
    LD_LIBRARY_PATH = "${
      lib.makeLibraryPath buildInputs
    }:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    LIBCLANG_PATH = "${pkgs.llvmPackages_12.libclang}/lib";
    LLVM_SYS_120_PREFIX = "${pkgs.llvmPackages_12.libllvm}";
    LLVM_CONFIG_PATH = "${pkgs.llvmPackages_12.llvm}/bin/llvm-config";
    RUST_BACKTRACE = "1";
    RUSTFLAGS = "-C target-cpu=native";
    CUDA_HOME = "${pkgs.cudaPackages.cuda_cudart}";
    CUDA_PATH = "${pkgs.cudaPackages.cuda_cudart}";
  };

  languages = {
    python = {
      enable = true;
      version = "3.11.9";
      uv = {
        enable = true;
        sync = {
          enable = true;
          pyproject = true;
          requirements = true;
        };
      };
      packages = pythonPackages;
    };
    rust = {
      enable = true;
      channel = "stable";
    };
  };

  processes = {
    nvidia-monitor.exec = "nvidia-smi -l 1";
  };

  pre-commit.hooks = {
    black.enable = true;
    isort.enable = true;
    rustfmt.enable = true;
  };

  enterShell = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    echo "Python version: $(python --version)"
    echo "CUDA version: $(nvcc --version)"
    echo "Rust version: $(rustc --version)"
  '';

  # Build and deployment tasks
  tasks = {
    "build".exec = ''
      cargo build --release
    '';
    "test".exec = ''
      cargo test
      python -m pytest
    '';
    "run".exec = ''
      python app/main.py
    '';
  };
}