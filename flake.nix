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
  inherit (nixpkgs) lib;
  
  # Add uv2nix workspace setup
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };
  pkgs = nixpkgs.legacyPackages.${system};
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
    ];
    
    shellHook = ''
      export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.libGL
        pkgs.libGLU
        pkgs.xorg.libX11
        pkgs.mesa
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.glib
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
