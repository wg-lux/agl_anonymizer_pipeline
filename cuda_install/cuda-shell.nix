# Run with `nix-shell cuda-shell.nix`
{ pkgs ? import <nixpkgs> {config = {allowUnfree = true;};} }:
pkgs.mkShell {
   name = "cuda-env-shell";
   buildInputs = with pkgs; [
     git gitRepo gnupg autoconf curl
     procps gnumake util-linux m4 gperf unzip
     cudatoolkit linuxPackages.nvidia_x11
     libGLU libGL
     xorg.libXi xorg.libXmu freeglut
     xorg.libXext xorg.libX11 xorg.libXv xorg.libXrandr zlib 
     ncurses5 stdenv.cc binutils
     cudaPackages.cudatoolkit
   ];
   shellHook = ''
      export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
      # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
      export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
      export EXTRA_CCFLAGS="-I/usr/include"
      export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit}/lib64:$LD_LIBRARY_PATH
      export EXTRA_LDFLAGS="-L${pkgs.cudaPackages.cudatoolkit}/lib64"
      export EXTRA_CCFLAGS="-I${pkgs.cudaPackages.cudatoolkit}/include"
      export PATH=${pkgs.cudaPackages.cudatoolkit}/bin:$PATH

   '';          
}