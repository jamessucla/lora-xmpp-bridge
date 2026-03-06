# SovereignRelay

SovereignRelay is an off-grid resilient communication bridge built with NixOS. It connects local Meshtastic LoRa mesh networks to the federated internet via XMPP.

If the internet goes down, locals can communicate over the Meshtastic LoRa mesh. When the internet is up, a NixOS bridge flawlessly forwards local mesh messages to a federated XMPP Multi-User Chat (MUC) and vice versa, keeping the off-grid community connected to the broader world.

## Architecture

* **The Edge:** Local users connected to Meshtastic LoRa radios (e.g., LILYGO T-Beams or RAK WisBlocks).
* **The Bridge Hardware:** A machine (like a laptop or Raspberry Pi) running NixOS. A Meshtastic radio connects to it via USB (Serial).
* **The Bridge Software:** A Python daemon that actively listens to the Meshtastic serial stream and an XMPP connection.
* **The Federated Layer:** XMPP server facilitating connections globally.

## Prerequisites
- A local NixOS installation with flakes enabled.
- A Meshtastic device connected via USB to the NixOS machine.
- An XMPP account that can join MUCs.

## Usage

### Using the Nix Flake directly

You can run the python bridge straight from the flake:

```bash
nix run . -- -j "your_jid@xmpp.org" -p "your_password" -r "your_room@conference.xmpp.org" -n "meshbridge"
```

### Developing

You can drop into a Nix shell with all the required python dependencies:

```bash
nix develop
```

### NixOS Module (Systemd Service)

SovereignRelay provides a NixOS module to seamlessly integrate the bridge as a declarative `systemd` service that will persist, automatically start on boot, and autorestart on failure.

Include the flake in your NixOS configuration's `flake.nix` inputs:

```nix
{
  inputs.sovereign-relay.url = "github:jshiffer/lora-xmpp-bridge";
  # ...
}
```

Then in your NixOS configuration (e.g., `configuration.nix`):

```nix
{
  imports = [
    inputs.sovereign-relay.nixosModules.default
  ];

  services.sovereign-bridge = {
    enable = true;
    jid = "your_jid@xmpp.org";
    passwordFile = "/run/secrets/xmpp_password";
    room = "your_room@conference.xmpp.org";
    nick = "meshbridge";
  };
}
```

#### Managing the XMPP Password

The `passwordFile` option ensures the XMPP password isn't leaked into the world-readable Nix store or process arguments. The daemon reads the file directly.

For a rapid 24-hour hackathon, you can simply create this file manually on the target machine:

```bash
sudo mkdir -p /run/secrets
echo "my_super_secret_password" | sudo tee /run/secrets/xmpp_password
sudo chown root:root /run/secrets/xmpp_password
sudo chmod 600 /run/secrets/xmpp_password
```

*(For a production system, you would use a secret management tool like `sops-nix` or `agenix` to declaratively deploy this file).*

#### Reproducing from a Fresh NixOS Install

To deploy this on a fresh NixOS system for the hackathon:

1. Connect your Meshtastic node via USB.
2. Ensure flakes are enabled on your fresh install (add `nix.settings.experimental-features = [ "nix-command" "flakes" ];` to your configuration).
3. Create your configuration flake (e.g., in `/etc/nixos/flake.nix`) that includes the `sovereign-bridge` module and configuration block as shown above.
4. Create the password file: `echo "yourpassword" | sudo tee /run/secrets/xmpp_password && sudo chmod 600 /run/secrets/xmpp_password`.
5. Apply the configuration: `sudo nixos-rebuild switch --flake /etc/nixos#yourhostname`.
6. Verify it's running: `systemctl status sovereign-bridge.service`.