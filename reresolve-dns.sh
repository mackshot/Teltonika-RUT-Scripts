#!/bin/ash

STATUS=`wg show`
TIMEOUT=125
DEBUG=0

EPOCHSECONDS=`date +%s`
IFS=$'\n'
UCI_PUBLIC_KEY=`uci show | grep -E ^network\..*\.public_key=`
UCI_ENDPOINT_HOST=`uci show | grep -E ^network\..*\.endpoint_host=`
UCI_ENDPOINT_PORT=`uci show | grep -E ^network\..*\.endpoint_port=`
for i in $STATUS; do
  if [ $(expr "$i" : "interface: ") -ne 0 ]; then
    INTERFACE=`echo $i | sed -nE 's/interface: (.+)/\1/ip'`
    HANDSHAKES=`wg show $INTERFACE latest-handshakes`
    for j in $HANDSHAKES; do
      PUBKEY=`echo $j | sed -nE 's/(.*=)[[:space:]]+([0-9]+)/\1/ip'`
      TIME=`echo $j | sed -nE 's/.*[[:space:]]+([0-9]+)/\1/ip'`
      for k in $UCI_PUBLIC_KEY; do
        MATCH=`echo $k | grep $PUBKEY | wc -c`
        if [ $MATCH -ne 0 ]; then
          PEER=`echo $k | sed -nE 's/network\.(.*)\..*/\1/ip'`
        fi
      done
      PEER_REGEX=`echo $PEER | sed 's/\[/./' | sed 's/\]/./'`
      HOST=`uci show | grep -E ^network\.$PEER_REGEX\.endpoint_host= | sed -nE 's/.*=(.*)/\1/ip' | tr -d \'`
      PORT=`uci show | grep -E ^network\.$PEER_REGEX\.endpoint_port= | sed -nE 's/.*=(.*)/\1/ip' | tr -d \'`
      if [ $(($EPOCHSECONDS - $TIME)) -gt $TIMEOUT ]; then
        if [ $DEBUG -eq 1 ]; then
          echo update ${PEER}@${INTERFACE}
        fi
        `wg set "$INTERFACE" peer "$PUBKEY" endpoint "${HOST}:${PORT}"`
      fi
    done
  fi
done
