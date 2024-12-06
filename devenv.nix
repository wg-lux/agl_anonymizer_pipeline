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
  buildInputs = with pkgs [
    python311
  ];

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
  # Combine common packages with conditional CUDA packages
  buildInputs = commonPackages ++ cudaPackages;

  # Combined environment variables
  env = {
    LD_LIBRARY_PATH = "${lib.makeLibraryPath pkgs.buildInputs}:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    NIX_PATH = "nixpkgs=${pkgs.path}";
    PYTHON_VERSION = "3.11.9";
    CUDA_ENABLED = if isCudaSupported then "1" else "0";
  } // platformEnv;

  # Basic language support
  languages.python = {
    enable = true;
    package = pkgs.python311;
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  # Simple shell initialization
  enterShell = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    export NIX_PATH="nixpkgs=${pkgs.path}"
    export PYTHON_VERSION="3.11.9"
    export CUDA_ENABLED=${if isCudaSupported then "1" else "0"}
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
