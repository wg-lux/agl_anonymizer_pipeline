{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem (system:
        let
          # Fetching MuPDF from GitHub

          # Adding the overlays to the nixpkgs import
          pkgs = import nixpkgs {
            inherit system;
            overlays = [

              (final: prev: {
                ghostpdl = final.fetchurl {
                  url = "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10040/ghostpdl-10.04.0.tar.gz";
                  sha256 = "01f2dlqhqpqxjljkf5wp65cvmfpnxras4w42h5pkh3p0cyq985cb";
                };

                mupdf = prev.mupdf.overrideAttrs (old: {
                  preInstall = ''
                    tar -xzf ${final.ghostpdl}
                  '';

                  nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                    final.pkg-config
                    final.libclang
                    final.ghostpdl
                  ];

                  buildInputs = old.buildInputs or [] ++ [
                    # Include necessary dependencies
                    prev.autoPatchelfHook
                    prev.openjpeg
                    prev.jbig2dec
                    prev.freetype
                    prev.harfbuzz
                    prev.gumbo
                    prev.freeglut
                    prev.libGLU
                    prev.libjpeg_turbo
                    # Add tesseract if needed
                    prev.tesseract
                  ];
                  src = prev.fetchFromGitHub {
                    owner = "ArtifexSoftware";
                    repo = "mupdf";
                    rev = "master";  # You can specify a specific commit or tag
                    sha256 = "0vyjzm5pgscb6xxlp862mclykd5qvywcwdp3pahlmg17p6cx4234";  # Use 'nix-prefetch-git' to get the actual hash
                  };
                  patches = [];
                  makeFlags = old.makeFlags or [];  # Preserve existing makeFlags
                });

                pymupdf = prev.python312Packages.pymupdf.overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                    final.mupdf
                    final.pkg-config
                    final.libclang
                    final.python312Packages.setuptools
                  ];
                  postInstall = ''
                    echo "Linking mupdf libraries"
                    export LD_LIBRARY_PATH="${final.mupdf}/lib:$LD_LIBRARY_PATH"
                    find $out/lib/python3.12/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.mupdf}/lib {} \;
                  '';
                });
              })
            ];
          };
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                # https://devenv.sh/reference/options/
                packages = [ pkgs.hello pkgs.mupdf pkgs.pymupdf ];

                enterShell = ''
                  hello
                '';

                processes.hello.exec = "hello";
              }
            ];
          };
        });
    };
}
