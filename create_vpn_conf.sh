#!/bin/sh

OVPN="/vagrant/config.ovpn"
CONF="/etc/openvpn/vpn.conf"

if [ -f $OVPN ]; then
	echo "Copying $OVPN to $CONF"
	sudo cp $OVPN $CONF
else
	echo "Run `vagrant get-config` first."
fi
