{
  description = "Flake for the agl_anonymizer_pipeline service with CUDA support";
  nixConfig = {
      substituters = [
        "https://cache.nixos.org"
        "https://cuda-maintainers.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      
      # Add these important settings
      substitute = true;  # Enable substitution
      trust-substituters = true;  # Trust binary caches
      builders-use-substitutes = true;  # Allow builders to use substitutes
      extra-sandbox-paths = [
        "/usr/lib64/"
      ];
      sandbox = false;  # Disable the sandbox for building
    };
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
      # Configuration for binary caches and keys

  };

  outputs = { self, nixpkgs, devenv, pyproject-nix, uv2nix, pyproject-build-systems, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {

          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;  # Enable CUDA support in the configuration
            allowBroken = true;  # Allow broken packages for development
          };
        };
      inherit (nixpkgs) lib;
      
      # Add uv2nix workspace setup
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      
      pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
        python = pkgs.python311;
      }).overrideScope (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
          (final: prev: {
          # Override problematic packages here
          fst-pso = pkgs.python311Packages.fst-pso;
          accelerate = pkgs.python311Packages.accelerate;
          # If needed, you can also override uv:
          # uv = pkgs.uv;
        })
        ]
      );
    in {
      devShells.${system} = {
        agl_anonymizer_pipeline = devenv.lib.mkShell {
          inherit inputs pkgs;
          
          modules = [{
            packages = with pkgs; [
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

                    # Fix the environment variable definition
            env.PYTHON_VENV = let
              venv = pythonSet.mkVirtualEnv "project-a-env" workspace.deps.all;
              in "${venv}/bin"; # Make sure we get a proper path

            languages.python = {
              enable = true;
              package = pkgs.python311;
              uv.enable = true;
            };

            enterShell = ''
              echo "Entering agl_anonymizer_pipeline environment"
              . $PYTHON_VENV/bin/activate
            '';
          }];
        };

        projectB = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [{
            enterShell = ''
              echo "this is project B"
            '';
          }];
        };
      };

      packages.${system} = {
        agl_anonymizer_pipeline-devenv-up = self.devShells.${system}.agl_anonymizer_pipeline.config.procfileScript;
        agl_anonymizer_pipeline-devenv-test = self.devShells.${system}.agl_anonymizer_pipeline.config.test;
        projectB-devenv-up = self.devShells.${system}.projectB.config.procfileScript;
        projectB-devenv-test = self.devShells.${system}.projectB.config.test;
      };
    };
}