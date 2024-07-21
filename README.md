# Teltonika RUT Scripts Collection

This is a collection of useful Scripts für Teltonika RUT devices.

Scripts are tested on
- RUT 240, Firmware
  - RUT2_R_00.07.06.13
- RUT 950, Firmware
  - not tested

(Feel free to add new supported firmwares to the list via a pull request.)

                                    
## 1. WireGuard: Reresolve Dynamic DNS

Since WireGuard does not reresolve dynamic DNS entries regulary connections to those peers cannot be reestablished.

Inspired by https://github.com/WireGuard/wireguard-tools/tree/master/contrib/reresolve-dns `reresolve-dns.sh` provides an automatic (dns) update for peers with no handshake for more than 125 seconds.

This script can be ran regularly by using cron

`*/5 * * * * /root/reresolve-dns.sh`

## 2. Geolocation tracking: Report Geolocation to Traccar or similar service using Google Geolocation API and OsmAnd Protocol

This script can be used to track geolocation using Google Geolocation API and OsmAnd Protocol. Please note, that right now the script only works if there is a LTE connection available. For geolocating mainly the available WIFI connections are used.

To avoid unneccessary calls against Google API geolocation service is only called when the network connected to has changed. This can be disabled by setting `IgnoreCache=1`.

Please make sure to set `GoogleApiKey`, `TrackingEndpoint` (using OsmAnd Protocol) and `TrackingDeviceId`.

This script can be ran regularly by using cron

`*/5 * * * * /root/geolocate.sh`

## Notes

All scripts must be make executeable `chmod u+x FILENAME`