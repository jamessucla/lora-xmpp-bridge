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

Include the flake in your `flake.nix` inputs:

```nix
{
  inputs.sovereign-relay.url = "github:yourusername/sovereign-relay";
  # ...
}
```

Then in your NixOS configuration (`configuration.nix` or similar):

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

The bridge daemon requires the `dialout` group to read the serial interface from the Meshtastic USB connection, which is handled automatically by the module's configuration.