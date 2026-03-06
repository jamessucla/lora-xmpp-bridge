{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sovereign-bridge;
  # Import the package defined in default.nix
  sovereign-bridge = import ./default.nix { inherit pkgs; };
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
        LoadCredential = "xmpp_password:${cfg.passwordFile}";
        ExecStart = let
          script = pkgs.writeShellScript "sovereign-bridge-start" ''
            # Run the bridge
            ${sovereign-bridge}/bin/sovereign-bridge \
              -j ${lib.escapeShellArg cfg.jid} \
              -P "$CREDENTIALS_DIRECTORY/xmpp_password" \
              -r ${lib.escapeShellArg cfg.room} \
              -n ${lib.escapeShellArg cfg.nick}
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
}