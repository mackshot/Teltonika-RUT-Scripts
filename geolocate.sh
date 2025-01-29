#!/bin/ash

# https://wiki.teltonika-networks.com/view/Gsmctl_commands
# https://community.teltonika-networks.com/38925/help-with-gsmctl-commands
# https://community.teltonika-networks.com/5088/gsmctl-k-output

GoogleApiKey=""
TrackingEndpoint=""
TrackingDeviceId=""
IgnoreCache=0

DEBUG=0
CacheFile="/tmp/geolocate.cache"

serving=`gsmctl -K`
RT=`echo $serving | awk -F, '{print $3}' | tr -d \"`
MCC=`echo $serving | awk -F, '{print $5}' | sed 's/^0*//'`
MNC=`echo $serving | awk -F, '{print $6}' | sed 's/^0*//'`
CELL=`echo $serving | awk -F, '{print "0x"$7}' | xargs printf "%d"`

CARRIER=`gsmctl -o`

if [[ "$RT" == "LTE" ]]; then
  RT="lte"
else
  exit 1
fi

connected=0
wifiCurrent="00"
iwinfo=`iw dev`
wlaninterface=""
wlanssid=""
wlanaddr=""
IFS=$'\n'
for i in $iwinfo; do
  MATCH=`echo $i | grep 'Interface ' | wc -c`
  if [ $MATCH -ne 0 ]; then
    wlanssid=""
    wlanaddr=""
    wlaninterface=`echo $i | sed -nE 's/.*Interface (.*)/\1/ip'`
  fi
  MATCH=`echo $i | grep 'addr ' | wc -c`
  if [ $MATCH -ne 0 ]; then
    wlanaddr=`echo $i | sed -nE 's/.*addr (.*)/\1/ip'`
  fi
  MATCH=`echo $i | grep 'ssid ' | wc -c`
  if [ $MATCH -ne 0 ]; then
    wlanssid=`echo $i | sed -nE 's/.*ssid (.*)/\1/ip'`
  fi
  MATCH=`echo $i | grep 'type managed' | wc -c`
  if [ $MATCH -ne 0 ]; then
    if [[ "$wlanssid" != "" ]]; then
      wifiCurrent="$wlanaddr"
      connected=1
    fi
    break
  fi  
done

cacheContent=`[ -f ${CacheFile} ] && cat ${CacheFile}`
match=`echo $cacheContent | grep '$wifiCurrent' | wc -c`
if [ $connected -ne 0 ] && [ $IgnoreCache -ne 1 ] && [ $match -ne 0 ]; then
  addr=`cat ${CacheFile} | sed -n 2p`
  curl $addr
  exit 0
fi

wifiAccessPoints=""
wifiscan=`iw wlan0 scan`
wifiscan=`echo $wifiscan | tr '\011\012\013\014\015\040' ' '`
wifis=`echo $wifiscan | sed -r 's/BSS /\n/g'`
IFS=$'\n'
for i in $wifis; do
  mac=`echo $i | sed -nE 's/.*(.{2}:.{2}:.{2}:.{2}:.{2}:.{2}).*/\1/ip'`
  signalStrength=`echo $i | sed -nE 's/.*signal: (-[0-9]+).*/\1/ip'`
  channel=`echo $i | sed -nE 's/.*primary channel: ([0-9]+).*/\1/ip'`
  ago=`echo $i | sed -nE 's/.*last seen: ([0-9]+) ms ago.*/\1/ip'`
  if [[ "$mac" != "" ]]; then
    wifiAccessPoints="$wifiAccessPoints, {\"macAddress\": \"$mac\""
    if [[ "$signalStrength" != "" ]]; then
      wifiAccessPoints="$wifiAccessPoints,\"signalStrength\": \"$signalStrength\""
    fi
    if [[ "$channel" != "" ]]; then
      wifiAccessPoints="$wifiAccessPoints,\"channel\": \"$channel\""
    fi
    if [[ "$ago" != "" ]]; then
      wifiAccessPoints="$wifiAccessPoints,\"ago\": \"$ago\""
    fi
    wifiAccessPoints="$wifiAccessPoints }"
  fi
done
wifiAccessPoints="${wifiAccessPoints:1}"

cellTowers="{ "cellId": $CELL, "mobileCountryCode": $MCC, "mobileNetworkCode": $MNC, "age": 0 }"

requestBody=$(cat <<-END
{
  "homeMobileCountryCode": $MCC,
  "homeMobileNetworkCode": $MNC,
  "radioType": "$RT",
  "carrier": "$CARRIER",
  "considerIp": false,
  "wifiAccessPoints": [${wifiAccessPoints}],
  "cellTowers": [$cellTowers]
}
END
)

if [ $DEBUG -eq 1 ]; then
  echo $requestBody
fi

# https://developers.google.com/maps/documentation/geolocation/overview
location=`curl --data "${requestBody}" -H "Content-Type: application/json" https://www.googleapis.com/geolocation/v1/geolocate?key=${GoogleApiKey}`
notfound=`echo $location | sed -E 's/.*"(Not Found)".*/\1/'`
if [[ "$notfound" == "Not Found" ]]; then
  echo $notfound
  exit 1
fi

lat=`echo $location | sed -E 's/.*"lat": (-?[0-9]+.[0-9]+).*/\1/'`
lon=`echo $location | sed -E 's/.*"lng": (-?[0-9]+.[0-9]+).*/\1/'`
accuracy=`echo $location | sed -E 's/.*"accuracy": ([0-9]+).*/\1/'`
if [ $DEBUG -eq 1 ]; then
  echo $lat
  echo $lon
  echo $accuracy
fi

trackingRequest="${TrackingEndpoint}/?id=${TrackingDeviceId}&lat=${lat}&lon=${lon}&accuracy=${accuracy}"
if [ $connected -eq 0 ]; then
  echo $RANDOM | md5sum | head -c 20 > $CacheFile
  echo '' >> $CacheFile
else
  echo $wifiCurrent > $CacheFile
fi
echo $trackingRequest >> $CacheFile

curl $trackingRequest