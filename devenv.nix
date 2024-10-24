{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ 
    pkgs.git
    pkgs.python312
    pkgs.gccPkg.libc
    pkgs.python312Packages.setuptools
    pkgs.python312Packages.numpy
    pkgs.python312Packages.importlib_metadata
    pkgs.python312Packages.transformers
    pkgs.python312Packages.torch
    pkgs.python312Packages.torchvision
    pkgs.python312Packages.torchaudio
    pkgs.python312Packages.spacy
    pkgs.python312Packages.spacy-lookups-data
    pkgs.python312Packages.opencv-python-headless
    pkgs.harfbuzz
    pkgs.freetype
    pkgs.libclang
    pkgs.pkg-config
    pkgs.autoPatchelfHook
    pkgs.openjpeg
    pkgs.jbig2dec
    pkgs.gumbo
    pkgs.freeglut
    pkgs.libGLU
    pkgs.libjpeg_turbo
    pkgs.tesseract
    pkgs.clang-tools
    
    ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    hello
    git --version
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
