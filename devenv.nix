{ pkgs, lib, config, ... }:
let
  buildInputs = with pkgs; [
    python311Full
    stdenv.cc.cc
    zlib
    mesa
    glibc
    opencv
    cudaPackages.cudatoolkit
    linuxPackages.nvidia_x11
    libGLU
    libGL
    xorg.libXi
    xorg.libXmu
    freeglut
    pkg-config
  ];
in
{
  env = {
    LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
  };

  languages.python = {
    enable = true;
    package = pkgs.python311;
    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  processes.my_python_app = {
    exec = "python agl_anonymizer_pipeline/main.py --image images/lebron_james.jpg";
    process-compose = {
      enabled = true;
      output.stdout = true;
      output.stderr = true;
    };
  };

  cachix.enable = false;
}