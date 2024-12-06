# First, let's create the .envrc file
cat > .envrc << 'EOL'
use flake
EOL

# Now let's update the devenv.nix with the correct configuration
cat > devenv.nix << 'EOL'
{ pkgs, lib, ... }:

{
  # Enable NIX_PATH for legacy nix commands
  env.NIX_PATH = "nixpkgs=${pkgs.path}";
  
  # Languages
  languages = {
    python = {
      enable = true;
      version = "3.11.9";
      venv.enable = true;
      uv.enable = true;
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
    if command -v nvcc &> /dev/null; then
      echo "CUDA $(nvcc --version)"
    else
      echo "CUDA not available"
    fi
  '';

  # Processes for development
  processes.dev.exec = "python app/main.py";
}
EOL

# Update devenv.yaml to be simpler
cat > devenv.yaml << 'EOL'
allowUnfree: true
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixos-23.11
  devenv:
    url: github:cachix/devenv
EOL

# Add and commit the new files
git add .envrc devenv.nix devenv.yaml
git commit -m "Update devenv configuration"

# Allow direnv
direnv allow

# Initialize devenv
devenv up
EOL