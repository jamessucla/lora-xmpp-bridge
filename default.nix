{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    meshtastic
    slixmpp
  ]);
in
pkgs.writeScriptBin "sovereign-bridge" ''
  #!${pythonEnv}/bin/python
  ${builtins.readFile ./bridge.py}
''