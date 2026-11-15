{ pkgs ? import <nixpkgs> {} }:
with pkgs;

stdenv.mkDerivation {
  pname = "autolift";
  version = "v0.9.3";
  meta = with lib; {
    description = "Autofocus and lift windows on mouse hover";
    platforms = platforms.darwin;
    homepage = "https://github.com/antichrome1/autolift";
    license = licenses.isc;
    maintainers = [{ name = "Aditya Singh"; email = "antichrome1@proton.me"; }];
  };

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR

    make release

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 autolift $out/bin/autolift

    runHook postInstall
  '';
}
