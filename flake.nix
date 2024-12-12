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
      pkgs = nixpkgs.legacyPackages.${system};
      
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
        ]
      );
      
    in {
      packages.${system} = {
        projectA-devenv-up = self.devShells.${system}.projectA.config.procfileScript;
        projectA-devenv-test = self.devShells.${system}.projectA.config.test;
        projectB-devenv-up = self.devShells.${system}.projectB.config.procfileScript;
        projectB-devenv-test = self.devShells.${system}.projectB.config.test;
      };

      devShells.${system} = {
        projectA = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              # Include your devenv.nix configuration
              imports = [ ./devenv.nix ];
              
              # Add uv2nix virtual environment
              env.PYTHON_VENV = pythonSet.mkVirtualEnv "project-a-env" workspace.deps.all;
              
              enterShell = ''
                echo "this is project A"
                . $PYTHON_VENV/bin/activate
              '';
            }
          ];
        };
        
        projectB = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              enterShell = ''
                echo "this is project B"
              '';
            }
          ];
        };
      };
    };
}