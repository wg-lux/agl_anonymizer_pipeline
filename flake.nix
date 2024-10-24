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
          # Adding the overlays to the nixpkgs import
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                mupdf = prev.mupdf.overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                    final.pkg-config
                    final.libclang
                    final.harfbuzz
                    final.freetype
                  ];
                  buildInputs = old.buildInputs or [] ++ [
                    prev.autoPatchelfHook
                    prev.openjpeg
                    prev.jbig2dec
                    prev.gumbo
                    prev.freeglut
                    prev.libGLU
                    prev.libjpeg_turbo
                    prev.tesseract
                  ];
                  makeFlags = old.makeFlags or [];
                });

                pymupdf = prev.python311Packages.pymupdf.overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs or [] ++ [
                    final.mupdf
                    final.pkg-config
                    final.libclang
                  ];
                  postInstall = ''
                    echo "Linking mupdf libraries"
                    export LD_LIBRARY_PATH="${final.mupdf}/lib:$LD_LIBRARY_PATH"
                    find $out/lib/python3.11/site-packages/ -name "*.so" -exec patchelf --set-rpath ${final.mupdf}/lib {} \;
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
