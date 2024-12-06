{ pkgs, lib, ... }:

{
  # Enable NIX_PATH for legacy nix commands
  env.NIX_PATH = "nixpkgs=${pkgs.path}";
  
  # Languages
  languages = {
    python = {
      enable = true;
      version = "3.11.9";
      uv.enable = true;
      uv.sync = {
        enable = true;
        requirements = true;
      };
    };
    rust.enable = true;
  };

  # Packages
  packages = with pkgs; [
    python311
    python311Packages.pip
    python311Packages.setuptools
    python311Packages.wheel
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
    git
    mupdf
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
  ];

  env = {
    PYTHON_VERSION = "3.11.9";
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
      pkgs.cudaPackages.cuda_cudart
      pkgs.cudaPackages.cudnn
      "${pkgs.libglvnd}/lib"
    ] + ":/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    LIBCLANG_PATH = "${pkgs.llvmPackages_12.libclang}/lib";
    LLVM_SYS_120_PREFIX = "${pkgs.llvmPackages_12.libllvm}";
    CUDA_HOME = "${pkgs.cudaPackages.cuda_cudart}";
    CUDA_PATH = "${pkgs.cudaPackages.cuda_cudart}";
  };

  enterShell = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    echo "Python $(python --version)"
    echo "CUDA $(nvcc --version)"
  '';
}
