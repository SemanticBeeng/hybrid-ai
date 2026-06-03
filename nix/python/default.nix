{ pkgs ? import <nixpkgs> {} }:
let
  poetry2nix = pkgs.poetry2nix;
in
poetry2nix.mkPoetryApplication {
  projectDir = ../../src/python;
  python = pkgs.python311;
}
