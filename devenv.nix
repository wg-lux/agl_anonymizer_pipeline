{ pkgs, lib, config, inputs, ... }:
let

  buildInputs = with pkgs; [
    python311Full
    # cudaPackages.cuda_cudart
    # cudaPackages.cudnn
    stdenv.cc.cc
    # zlib
    # mesa
    glib
    glibc
    # opencv
  ];

in
{
  dotenv.enable = false;
  dotenv.disableHint = true;


  packages = with pkgs; [
    cudaPackages.cuda_nvcc
    stdenv.cc.cc
    # glibc
    # mesa
  ];

  env = {
    LD_LIBRARY_PATH = "${
      with pkgs;
      lib.makeLibraryPath buildInputs
    }:/run/opengl-driver/lib:/run/opengl-driver-32/lib";

  };


  languages.python = {
    enable = true;
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  # Einfache Shell-Initialisierung
  enterShell = ''
    . .devenv/state/venv/bin/activate
  '';

  scripts.run-anonymizer.exec =
    "${pkgs.uv}/bin/uv run python agl_anonymizer_pipeline/main.py --image images/lebron_james.jpg";

  # Definiere Prozesse
  processes = {
    my_python_app.exec = "run-anonymizer"; # "${pkgs.python311}/bin/python agl_anonymizer_pipeline/main.py --image images/lebron_james.jpg";
  };

  # Deaktiviere automatische Cache-Konfiguration
  cachix.enable = true;
}
