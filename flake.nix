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
  python = pkgs.python312;
      # Convert workspace deps to attribute set
      depsToAttrSet = deps: builtins.listToAttrs (map (dep: {
        name = if builtins.isString dep then dep else dep.name;
        value = {};
      }) deps);

      buildInputsOverlay = final: prev: {
        accelerate = prev.accelerate or (
          pkgs.python312Packages.accelerate.overridePythonAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
              pkgs.python312Packages.pip
              pkgs.python312Packages.wheel
              pkgs.python312Packages.setuptools
            ];
            # Remove uv-specific flags from the build process
            pipInstallFlags = [
              "--no-deps"
              "--prefix=${placeholder "out"}"
            ];
          })
        );
        fst-pso = prev.fst-pso or pkgs.python312Packages.fst-pso;
      };


  pythonSet = 
  (pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
      buildInputsOverlay
    ]
  );
in {
  packages.x86_64-linux.default = pythonSet.mkVirtualEnv "agl_anonymizer_pipeline-env" workspace.deps.default;
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
