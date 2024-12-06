{ pkgs, lib, ... }:

let
  # Überprüfen, ob das System CUDA-kompatibel ist (x86_64-linux)
  isCudaSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # CUDA-Pakete, die nur auf unterstützten Systemen enthalten sind
  cudaPackages = if isCudaSupported then with pkgs; [
    cuda_cudart
    cudnn
    cuda_nvcc
  ] else [];
  
  # Gemeinsame Pakete für alle Plattformen
  commonPackages = with pkgs; [
    # Python und Build-Tools
    python311
    python311Packages.pip
    python311Packages.setuptools
    python311Packages.wheel
    git

    # Build-Tools
    pkg-config
    cmake

    # Bildverarbeitung
    tesseract
    mupdf
    harfbuzz
    freetype
    libjpeg_turbo
  ];

  # Kombinieren der gemeinsamen Pakete mit den bedingten CUDA-Paketen
  packagesList = commonPackages ++ cudaPackages;

  # Plattform-spezifische Umgebungsvariablen
  platformEnv = if isCudaSupported then {
    CUDA_HOME = "${pkgs.cuda_cudart}";
    CUDA_PATH = "${pkgs.cuda_cudart}";
  } else {
    DYLD_LIBRARY_PATH = lib.makeLibraryPath [
      pkgs.stdenv.cc.cc.lib
    ];
  };
in
{
  # Definiere die zu installierenden Pakete
  packages = packagesList;

  # Kombinierte Umgebungsvariablen
  env = {
    LD_LIBRARY_PATH = "${lib.makeLibraryPath packagesList}:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    NIX_PATH = "nixpkgs=${pkgs.path}";
    PYTHON_VERSION = "3.11.9";
    CUDA_ENABLED = if isCudaSupported then "1" else "0";
  } // platformEnv;

  # Grundlegende Sprachunterstützung
  languages.python = {
    enable = true;
    package = pkgs.python311;
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  # Einfache Shell-Initialisierung
  enterShell = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    export NIX_PATH="nixpkgs=${pkgs.path}"
    export PYTHON_VERSION="3.11.9"
    export CUDA_ENABLED=${if isCudaSupported then "1" else "0"}
    echo "Python $(python --version)"
    if [ "$CUDA_ENABLED" = "1" ]; then
      echo "CUDA ist aktiviert"
    else
      echo "CUDA ist auf dieser Plattform nicht verfügbar"
    fi
  '';

  # Definiere Prozesse
  processes.my_python_app = {
    exec = "${pkgs.python311}/bin/python agl_anonymizer_pipeline/main.py";
  };

  # Deaktiviere automatische Cache-Konfiguration
  cachix.enable = false;
}
