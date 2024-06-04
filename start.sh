#!/bin/bash

cat >/etc/ppp/pppoe-server-options <<-EOF
ms-dns ${PPPOE_DNS1:-1.1.1.1}
ms-dns ${PPPOE_DNS2:-1.0.0.1}
auth
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

## functions
build_pppwn () {
	rm -rf /usr/local/bin/pppwn
	echo "Cloning and building pppwn++"
	git clone https://github.com/xfangfang/PPPwn_cpp.git /tmp/pppwn
	cd /tmp/pppwn
	cmake -B build
	cmake --build build -t pppwn
	mv build/pppwn /usr/local/bin/pppwn
}

build_stages () {
	rm -rf /stages
	echo "Downloading and building latest stages"
	git clone --recursive -b goldhen https://github.com/SiSTR0/PPPwn /tmp/stages
	cd /tmp/stages
	mkdir /stages
	echo "Making stage 1 for ${FIRMWAREVERSION:-1100}"
	make -C stage1 FW="${FIRMWAREVERSION:-1100}" clean && make -C stage1 FW="${FIRMWAREVERSION:-1100}" && mv stage1/stage1.bin /stages/"${STAGE_1:-stage1_1100.bin}"
	echo "Making stage 2 for ${FIRMWAREVERSION:-1100}"
	make -C stage2 FW="${FIRMWAREVERSION:-1100}" clean && make -C stage2 FW="${FIRMWAREVERSION:-1100}" && mv stage2/stage2.bin /stages/"${STAGE_2:-stage2_1100.bin}"
}

check_stages () {
	if [ -f /stages/"${STAGE_1:-stage1_1100.bin}" ]; then
		if test "`find /stages/${STAGE_1:-stage1_1100.bin} -mmin +1440`"; then
			echo "Stages older than 24hr, building"
			build_stages
		else
			echo "Stages less than 24hr old, not rebuilding"
		fi
	else
		echo "Stage doesn't exist, building"
		build_stages
	fi
}

check_pppwn () {
	if [ -f /usr/local/bin/pppwn ]; then
		if test "`find /usr/local/bin/pppwn -mmin +1440`"; then
			echo "PPPwn exists but older than 24hr, building"
			build_pppwn
		else
			echo "PPPwn exists but newer than 24hr, not building"
			check_stages
		fi
	else
		echo "PPPwn doesn't exist, building"
		build_pppwn
		check_stages
	fi
}

echo "Setting sysctl forwarding config"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1

echo "Clean up git dirs"
rm -rf /tmp/pppwn
rm -rf /tmp/stages

echo "Check for bins and clean up"
check_pppwn

echo "Starting pppwn++"
until /usr/local/bin/pppwn --interface "${PPPOE_IFACE:-eth0}" --fw "${FIRMWAREVERSION:-1100}" --stage1 /stages/"${STAGE_1:-stage1_1100.bin}" --stage2 /stages/"${STAGE_2:-stage2_1100.bin}" --auto-retry;
do
	echo "Trying again unclean exit";
done

echo "Starting PPPoE server"
pppoe-server -T 60 -C PS4 -S PS4 -I "${PPPOE_IFACE:-eth0}" -L "${PPPOE_LOCAL:-192.168.2.1}" -R "${PPPOE_REMOTE:-192.168.2.2}" -N "${PPPOE_NUM:-1}"
touch /var/log/pppd.log

echo "Setting up iptables masquerading"
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -I PREROUTING -p tcp --dport 2121 -j DNAT --to 192.168.2.2:2121
iptables -t nat -I PREROUTING -p tcp --dport 3232 -j DNAT --to 192.168.2.2:3232
iptables -t nat -I PREROUTING -p tcp --dport 9090 -j DNAT --to 192.168.2.2:9090
iptables -t nat -I PREROUTING -p tcp --dport 12800 -j DNAT --to 192.168.2.2:12800
iptables -t nat -I PREROUTING -p tcp --dport 12801 -j DNAT --to 192.168.2.2:12801
iptables -t nat -I PREROUTING -p tcp --dport 1337 -j DNAT --to 192.168.2.2:1337
iptables -t nat -A POSTROUTING -s "${PPPOE_SUBNET:-192.168.2.0}/24" ! -d "${PPPOE_SUBNET:-192.168.2.0}/24" -j MASQUERADE
tail -f /var/log/pppd.log
