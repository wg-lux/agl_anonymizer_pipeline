{ pkgs, lib, ... }:

let
  # Check if we're on a CUDA-compatible system (x86_64-linux)
  isCudaSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # CUDA packages that will only be included on supported systems
  cudaPackages = if isCudaSupported then with pkgs; [
    cudaPackages.cuda_cudart
    cudaPackages.cudnn
    cudaPackages.cuda_nvcc
  ] else [];

  # Common packages for all platforms
  commonPackages = with pkgs; [
    # Python and build tools
    python311
    python311Packages.pip
    python311Packages.setuptools
    python311Packages.wheel
    git
    
    # Build tools
    pkg-config
    cmake
    
    # Image processing
    tesseract
    mupdf
    harfbuzz
    freetype
    libjpeg_turbo
  ];

  # Platform-specific environment variables
  platformEnv = if isCudaSupported then {
    CUDA_HOME = "${pkgs.cudaPackages.cuda_cudart}";
    CUDA_PATH = "${pkgs.cudaPackages.cuda_cudart}";
  } else {
    DYLD_LIBRARY_PATH = lib.makeLibraryPath [
      "${pkgs.stdenv.cc.cc.lib}"
    ];
  };
in
{
  # Basic language support
  languages.python = {
    enable = true;
    package = pkgs.python311;
    venv.enable = true;
  };

  # Combine common packages with conditional CUDA packages
  packages = commonPackages ++ cudaPackages;

  # Combined environment variables
  env = {
    NIX_PATH = "nixpkgs=${pkgs.path}";
    PYTHON_VERSION = "3.11.9";
    CUDA_ENABLED = if isCudaSupported then "1" else "0";
  } // platformEnv;

  # Simple shell initialization
  enterShell = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    echo "Python $(python --version)"
    if [ "$CUDA_ENABLED" = "1" ]; then
      echo "CUDA is enabled"
    else
      echo "CUDA is not available on this platform"
    fi
  '';

  # Define processes
  processes.my_python_app = {
    exec = "${pkgs.python311}/bin/python agl_anonymizer_pipeline/main.py";
  };

  # Disable automatic cache configuration
  cachix.enable = false;
}
