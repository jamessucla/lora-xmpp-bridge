# SovereignRelay

SovereignRelay is an off-grid resilient communication bridge built with NixOS. It connects local Meshtastic LoRa mesh networks to the federated internet via XMPP.

If the internet goes down, locals can communicate over the Meshtastic LoRa mesh. When the internet is up, a NixOS bridge flawlessly forwards local mesh messages to a federated XMPP Multi-User Chat (MUC) and vice versa, keeping the off-grid community connected to the broader world.

## Architecture

* **The Edge:** Local users connected to Meshtastic LoRa radios (e.g., LILYGO T-Beams or RAK WisBlocks).
* **The Bridge Hardware:** A machine (like a laptop or Raspberry Pi) running NixOS. A Meshtastic radio connects to it via USB (Serial).
* **The Bridge Software:** A Python daemon that actively listens to the Meshtastic serial stream and an XMPP connection.
* **The Federated Layer:** XMPP server facilitating connections globally.

## Prerequisites
- A local NixOS installation.
- A Meshtastic device connected via USB to the NixOS machine.
- An XMPP account that can join MUCs.

## Usage

### Developing

You can drop into a Nix shell with all the required python dependencies:

```bash
nix-shell
```

From here you can run the bridge directly:
```bash
sovereign-bridge -j "your_jid@xmpp.org" -p "your_password" -r "your_room@conference.xmpp.org" -n "meshbridge"
```

### NixOS Module (Systemd Service)

SovereignRelay provides a NixOS module to seamlessly integrate the bridge as a declarative `systemd` service that will persist, automatically start on boot, and autorestart on failure.

Clone this repository to your NixOS machine:

```bash
git clone https://github.com/jamessucla/lora-xmpp-bridge.git /path/to/lora-xmpp-bridge
```

Then in your NixOS configuration (e.g., `/etc/nixos/configuration.nix`), import the `module.nix` file:

```nix
{
  imports = [
    /path/to/lora-xmpp-bridge/module.nix
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

To deploy this on a fresh NixOS system for the hackathon without experimental features:

1. Connect your Meshtastic node via USB.
2. If your fresh install doesn't have `git`, you can easily drop into a temporary shell that has it:
   ```bash
   nix-shell -p git
   ```
3. Clone this repository to the machine (we recommend placing it near your config):
   ```bash
   sudo git clone https://github.com/jamessucla/lora-xmpp-bridge.git /etc/nixos/lora-xmpp-bridge
   ```
4. Edit your `/etc/nixos/configuration.nix` to include the module and configuration block as shown above.
5. Create the password file: `echo "yourpassword" | sudo tee /run/secrets/xmpp_password && sudo chmod 600 /run/secrets/xmpp_password`.
6. **Protip for Raspberry Pi 3B+:** add 1GB of swap to prevent OOM during builds: `sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`.
7. Apply the configuration: `sudo nixos-rebuild switch`.
8. Verify it's running: `systemctl status sovereign-bridge.service`.
