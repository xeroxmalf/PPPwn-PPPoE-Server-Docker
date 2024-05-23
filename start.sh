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

cat >/etc/ppp/pap-secrets <<-EOF
"ppp" * "ppp" *
EOF

sleep 5

echo "Setting sysctl forwarding config"
sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.conf.all.route_localnet=1

#echo "Downloading latest nightly pppwn++"
#wget https://nightly.link/xfangfang/PPPwn_cpp/workflows/ci.yaml/main/x86_64-linux-musl.zip -O /tmp/pppwn.zip
#unzip /tmp/pppwn.zip -d /tmp
#tar xzvf /tmp/pppwn.tar.gz -C /tmp
#mv /tmp/pppwn /usr/local/bin/pppwn

echo "Cloning and building pppwn++ dev branch"
git clone -b dev https://github.com/xfangfang/PPPwn_cpp.git /tmp/pppwn
cd /tmp/pppwn
cmake -B build
cmake --build build -t pppwn
mv build/pppwn /usr/local/bin/pppwn

echo "Downloading and building latest stages"
git clone --recursive -b goldhen https://github.com/SiSTR0/PPPwn /tmp/stages
cd /tmp/stages
mkdir /stages
echo "Making stage 1 for ${FIRMWAREVERSION:-1100}"
make -C stage1 FW="${FIRMWAREVERSION:-1100}" clean && make -C stage1 FW="${FIRMWAREVERSION:-1100}" && mv stage1/stage1.bin /stages/"${STAGE_1:-stage1_1100.bin}"
echo "Making stage 2 for ${FIRMWAREVERSION:-1100}"
make -C stage2 FW="${FIRMWAREVERSION:-1100}" clean && make -C stage2 FW="${FIRMWAREVERSION:-1100}" && mv stage2/stage2.bin /stages/"${STAGE_2:-stage2_1100.bin}"

echo "Starting pppwn++"
until /usr/local/bin/pppwn --interface "${PPPOE_IFACE:-eth0}" --fw "${FIRMWAREVERSION:-1100}" --stage1 /stages/"${STAGE_1:-stage1_1100.bin}" --stage2 /stages/"${STAGE_2:-stage2_1100.bin}" --auto-retry;
do
	echo "Trying again unclean exit";
done

echo "Taking ${PPPOE_IFACE:-eth0} down"
ip link set "${PPPOE_IFACE:-eth0}" down
sleep 10

echo "Bringing ${PPPOE_IFACE:-eth0} up"
ip link set "${PPPOE_IFACE:-eth0}" up
sleep 10

echo "Starting PPPoE server"
pppoe-server -T 60 -C PS4 -S PS4 -I "${PPPOE_IFACE:-eth0}" -L "${PPPOE_LOCAL:-192.168.2.1}" -R "${PPPOE_REMOTE:-192.168.2.2}" -N "${PPPOE_NUM:-1}"
touch /var/log/pppd.log

echo "Setting up iptables masquerading"
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
#iptables -t nat -F
#iptables -t mangle -F
#iptables -F
#iptables -X
iptables -t nat -I PREROUTING -p tcp --dport 2121 -j DNAT --to 192.168.2.2:2121
iptables -t nat -I PREROUTING -p tcp --dport 3232 -j DNAT --to 192.168.2.2:3232
iptables -t nat -I PREROUTING -p tcp --dport 9090 -j DNAT --to 192.168.2.2:9090
iptables -t nat -I PREROUTING -p tcp --dport 12800 -j DNAT --to 192.168.2.2:12800
iptables -t nat -I PREROUTING -p tcp --dport 12801 -j DNAT --to 192.168.2.2:12801
iptables -t nat -I PREROUTING -p tcp --dport 1337 -j DNAT --to 192.168.2.2:1337
iptables -t nat -A POSTROUTING -s "${PPPOE_SUBNET:-192.168.2.0}/24" ! -d "${PPPOE_SUBNET:-192.168.2.0}/24" -j MASQUERADE
tail -f /var/log/pppd.log
