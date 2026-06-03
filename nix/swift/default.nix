{ pkgs ? import <nixpkgs> {} }:
let
  # Replace with your swiftpm2nix-generated lock and package derivation.
  swift = pkgs.swift;
in
pkgs.stdenv.mkDerivation {
  pname = "hybrid-ai-swift";
  version = "0.1.0";
  src = ../../src/swift;
  nativeBuildInputs = [ swift pkgs.cmake ];

  buildPhase = ''
    swift build --build-path $TMPDIR/swift-build
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out/src
  '';
}
