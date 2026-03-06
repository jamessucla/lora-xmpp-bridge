{
  description = "SovereignRelay - Meshtastic to XMPP Bridge";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Define the Python environment with required packages
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          meshtastic
          slixmpp
        ]);

        # Package the bridge script
        sovereign-bridge = pkgs.writeScriptBin "sovereign-bridge" ''
          #!${pythonEnv}/bin/python
          ${builtins.readFile ./bridge.py}
        '';

      in
      {
        packages.default = sovereign-bridge;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonEnv
            sovereign-bridge
          ];
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.sovereign-bridge;
        in {
          options.services.sovereign-bridge = {
            enable = mkEnableOption "SovereignRelay Bridge";

            jid = mkOption {
              type = types.str;
              description = "XMPP JID for the bridge bot";
            };

            passwordFile = mkOption {
              type = types.path;
              description = "Path to file containing XMPP password";
            };

            room = mkOption {
              type = types.str;
              description = "XMPP MUC room to bridge";
            };

            nick = mkOption {
              type = types.str;
              default = "meshbridge";
              description = "Nickname for the bridge bot in the MUC";
            };
          };

          config = mkIf cfg.enable {
            systemd.services.sovereign-bridge = {
              description = "SovereignRelay Meshtastic to XMPP Bridge";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                ExecStart = let
                  script = pkgs.writeShellScript "sovereign-bridge-start" ''
                    # Run the bridge
                    ${self.packages.${pkgs.system}.default}/bin/sovereign-bridge \
                      -j "${cfg.jid}" \
                      -P "${cfg.passwordFile}" \
                      -r "${cfg.room}" \
                      -n "${cfg.nick}"
                  '';
                in "${script}";
                Restart = "always";
                RestartSec = "10";
                # Required to access serial ports for Meshtastic
                SupplementaryGroups = [ "dialout" ];
                DynamicUser = true;
              };
            };
          };
        };
    };
}