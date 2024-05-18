#!/bin/bash

cat >/etc/ppp/pppoe-server-options <<-EOF
ms-dns ${PPPOE_DNS1:-1.1.1.1}
ms-dns ${PPPOE_DNS2:-1.0.0.1}
auth
proxyarp
debug 1
logfile /var/log/pppd.log
lcp-echo-failure 3
lcp-echo-interval 60
mtu 1482
mru 1482
require-pap
netmask 255.255.255.0
defaultroute
noipdefault
usepeerdns
EOF

cat >/etc/ppp/chap-secrets <<-EOF
"ppp" * "ppp" *
EOF

echo "Setting sysctl forwarding config"
sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.conf.all.route_localnet=1

echo "Starting pppwn++ and will kill after 3 minutes if it doesn't succeed"
timeout 180 /usr/local/bin/pppwn --interface "${PPPOE_IFACE:-eth0}" --fw "${FIRMWAREVERSION:-1100}" --stage1 /stages/stage1_"${FIRMWAREVERSION:-1100}".bin --stage2 /stages/stage2_"${FIRMWAREVERSION:-1100}".bin --auto-retry
sleep 5

echo "Setting up iptables masquerading"
subn=$(printf "%s" "${PPPOE_REMOTE:-192.168.2.2}" | sed 's/[0-9]\+$/0/g')
iptables -A POSTROUTING -t nat -s "$subn/24" -j MASQUERADE

echo "Starting PPPoE server"
pppoe-server -T 60 -C PS4 -S PS4 -I "${PPPOE_IFACE:-eth0}" -L "${PPPOE_LOCAL:-192.168.2.1}" -R "${PPPOE_REMOTE:-192.168.2.2}" -N "${PPPOE_NUM:-1}"
touch /var/log/pppd.log
tail -f /var/log/pppd.log
