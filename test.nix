{ pkgs ? import <nixpkgs> {} }:
let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    slixmpp
  ]);
in
pkgs.mkShell {
  buildInputs = [ pythonEnv ];
}
