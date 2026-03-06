import sys
import time
import logging
import asyncio
from pubsub import pub
import meshtastic
import meshtastic.serial_interface
import slixmpp

logging.basicConfig(level=logging.INFO, format='%(levelname)-8s %(message)s')

class SovereignBridge(slixmpp.ClientXMPP):
    def __init__(self, jid, password, room, nick):
        super().__init__(jid, password)
        self.room = room
        self.nick = nick
        self.meshtastic_interface = None

        # Plugins for MUC
        self.register_plugin('xep_0030') # Service Discovery
        self.register_plugin('xep_0045') # Multi-User Chat
        self.register_plugin('xep_0199') # XMPP Ping

        self.add_event_handler("session_start", self.start)
        self.add_event_handler("groupchat_message", self.muc_message)

        # Setup Meshtastic pubsub listeners
        pub.subscribe(self.on_meshtastic_receive, "meshtastic.receive.text")

    async def start(self, event):
        self.send_presence()
        await self.get_roster()
        self.plugin['xep_0045'].join_muc(self.room, self.nick)
        logging.info(f"Joined XMPP MUC: {self.room} as {self.nick}")

    def muc_message(self, msg):
        # Ignore our own messages to avoid loops
        if msg['mucnick'] == self.nick:
            return

        body = msg['body']
        sender = msg['mucnick']
        logging.info(f"[XMPP -> Meshtastic] {sender}: {body}")

        if self.meshtastic_interface:
            # Run the synchronous meshtastic call in a thread pool to avoid blocking asyncio
            asyncio.ensure_future(
                asyncio.to_thread(self._send_to_meshtastic, f"{sender}: {body}")
            )

    def _send_to_meshtastic(self, msg_text):
        try:
            self.meshtastic_interface.sendText(msg_text)
        except Exception as e:
            logging.error(f"Error sending to Meshtastic: {e}")

    def on_meshtastic_receive(self, packet, interface):
        try:
            if 'decoded' in packet and 'text' in packet['decoded']:
                text = packet['decoded']['text']
                sender_id = packet.get('fromId', 'Unknown')

                logging.info(f"[Meshtastic -> XMPP] {sender_id}: {text}")

                # Forward to XMPP MUC safely from the meshtastic pubsub thread
                self.loop.call_soon_threadsafe(self._send_xmpp_message, sender_id, text)
        except Exception as e:
            logging.error(f"Error processing Meshtastic packet: {e}")

    def _send_xmpp_message(self, sender_id, text):
        try:
            msg = self.make_message(mto=self.room, mbody=f"[{sender_id}] {text}", mtype='groupchat')
            msg.send()
        except Exception as e:
            logging.error(f"Error sending XMPP message: {e}")

    def connect_meshtastic(self):
        logging.info("Connecting to Meshtastic node...")
        try:
            # Connect to the first available serial port
            self.meshtastic_interface = meshtastic.serial_interface.SerialInterface()
            logging.info("Connected to Meshtastic node.")
        except Exception as e:
            logging.error(f"Could not connect to Meshtastic node: {e}")
            sys.exit(1)

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Meshtastic <-> XMPP Bridge")
    parser.add_argument("-j", "--jid", required=True, help="JID to use")
    parser.add_argument("-P", "--password-file", required=False, help="File containing password to use")
    parser.add_argument("-p", "--password", required=False, help="Password to use")
    parser.add_argument("-r", "--room", required=True, help="MUC room to join")
    parser.add_argument("-n", "--nick", required=True, help="MUC nickname")
    args = parser.parse_args()

    password = args.password
    if args.password_file:
        with open(args.password_file, 'r') as f:
            password = f.read().strip()

    if not password:
        parser.error("Either --password or --password-file is required")

    xmpp = SovereignBridge(args.jid, password, args.room, args.nick)
    xmpp.connect_meshtastic()

    logging.info("Connecting to XMPP server...")
    xmpp.connect()
    xmpp.process(forever=True)

if __name__ == '__main__':
    main()
