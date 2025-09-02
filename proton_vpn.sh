#!/bin/bash

# shell script to start, stop en show status of the Proton Wireguard VPN 

# use -x as the first argument to do cli debugging 
[ "$1" = "-x" ] && set -x && shift 1

VERSION="5.0.3 (August 2025)"
# release notes: as from version 5 I make it possible to have multiple config files.

# generate your own specific wireguard config file at your https://account.protonvpn.com/downloads
# place it in your home directory and make it hidden (by placing a dot in front of its name)
# replace the following INTERFACE variable with the name of your own config file, leaving out .conf at the end it will be added later on
# all interfaces must start with .wg- and end with .conf (eg: .wg-NL-476.conf)

# enter here the default interface, you should have at least one 
DEFAULT_INTERFACE=.wg-NL-237.conf
# path to where the interface(s) are located
CONFIG_PATH=$HOME

which -s wg-quick
[ $? -ne 0 ] && echo "install the wireguard package first (eg: sudo apt install wireguard)" && exit 1

function _INTERFACES {
for i in $(ls "$CONFIG_PATH"/.wg-*.conf)
do
	echo ${i##*/}
done
exit 0
}

function _SHOW_HELP {
echo "Usage: $0 [INTERFACE] [-s] [-u] [-d] [-h] [-i] [-l]

-s  give the status of Proton VPN
-u  start Proton VPN as a daemon
-d  stop Proton VPN daemon
-h  shows this info screen
-i  shows version
-l  list all interfaces"
}

function _VERSION {
echo -e "version: $VERSION

Copyright (C) 2024-2025 Albert van Alphen
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Albert van Alphen (albert.vanalphen@gmail.com)"
}

function _STATUS {
 LOC=$(ip addr show|awk 'BEGIN {FS=":"} $2~/.wg-/ {print $2}'|xargs)
 [ -z "$LOC" ] && STATUS=DOWN
}

function _VERBOSE_STATUS {
 _STATUS
 [ "${STATUS:-UP}" = "DOWN" ] && echo -e "Proton VPN is not running" && exit 1
 [ $LOC.conf != "$CONFIG_FILE" ] && echo "there is no vpn running for $CONFIG_FILE but there is one for $LOC.conf" && exit 1
 [ -n "$LOC" ] && INTERFACE=$LOC
 sudo wg show $INTERFACE
}

function _UP {
 _STATUS
 [ "${STATUS:-UP}" = "UP" ] && echo -e "Proton VPN is already running for interface $LOC.conf" && exit 1
 [ -z $LOC] && sudo wg-quick up $CONFIG
 _STATUS
}

function _DOWN {
 _STATUS
 [ -z "$LOC" ] && echo -e "Proton VPN is not running for interface $CONFIG_FILE" && exit 1
 [ "$CONFIG_PATH/$LOC.conf" != "$CONFIG" ] && echo -e "Proton VPN is not running for interface $CONFIG_FILE but for $LOC.conf" && exit 1
 [ "${STATUS:-UP}" = "DOWN" ] && echo -e "Proton VPN is not running for interface $CONFIG_FILE" && exit 1
 sudo wg-quick down $CONFIG
 _STATUS
}

if [ $# -eq 0 ] 
then 
	echo -e "missing argument\n" 
	_SHOW_HELP 
	exit 0
else
	CHK=$(echo $1|awk '($1~/^.wg-/ && $1~/.conf$/) {print "OK"}')
	[ "${CHK:=NO}" = OK ] && CONFIG_FILE=$1 && shift 1
	[ -z "$CONFIG_FILE" ] && CONFIG_FILE=$DEFAULT_INTERFACE
fi

CONFIG=${CONFIG_PATH}/${CONFIG_FILE}
[ ! -s "$CONFIG" ] && echo "missing or empty config file ($CONFIG)" && exit 1

ANSWER=$(echo $CONFIG_FILE|awk '($1~/^.wg-/ && $1~/.conf$/) {print "CFG"}')
[ -z "$ANSWER" ] && echo "no interfaces found" && exit 1
if [ "$ANSWER" = CFG ] && INTERFACE=${CONFIG_FILE%*.conf}
then
	CONFIG_FILE=${INTERFACE}.conf
	if [ ! -s "$CONFIG_PATH"/"$CONFIG_FILE" ]
	then
		echo -ne "no existing interface, continuing with default interface? (y/n) "
		read ANSWER
		case $ANSWER in
			n|N) exit 1 ;;
			*) 
		esac
	fi
else
	[ -z "$INTERFACE" ] && INTERFACE="$DEFAULT_INTERFACE"
fi

while getopts :sudhil opt
do
  case $opt in
		s) _VERBOSE_STATUS ;;
    u) _UP ;;
    d) _DOWN ;;
    h) _SHOW_HELP ;;
    i) _VERSION ;;
		l) _INTERFACES ;;
    \?) echo "Invalid option: -$OPTARG" >&2; _SHOW_HELP ;;
  esac
done
shift "$((OPTIND-1))"
