#!/bin/bash
# SL MOD + BW LIMIT + IP LIMIT
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
LIGHT='\033[0;37m'
MYIP=$(wget -qO- ipinfo.io/ip);
echo "Checking VPS"
IZIN=$( curl ipinfo.io/ip | grep $MYIP )
if [ $MYIP = $MYIP ]; then
echo -e "${NC}${GREEN}Permission Accepted...${NC}"
else
echo -e "${NC}${RED}Permission Denied!${NC}";
exit 0
fi
clear
if [[ "$IP" = "" ]]; then
PUBLIC_IP=$(wget -qO- ipinfo.io/ip);
else
PUBLIC_IP=$IP
fi
source /var/lib/crot/ipvps.conf
if [[ "$IP2" = "" ]]; then
domain=$(cat /etc/xray/domain)
else
domain=$IP2
fi
until [[ $VPN_USER =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
		read -rp "Username : " -e VPN_USER
		CLIENT_EXISTS=$(grep -w $VPN_USER /var/lib/crot/data-user-l2tp | wc -l)
		if [[ ${CLIENT_EXISTS} == '1' ]]; then
			echo ""
			echo -e "Username ${RED}${VPN_USER}${NC} Already On VPS Please Choose Another"
			exit 1
		fi
	done
read -p "Password : " VPN_PASSWORD
read -p "Expired (Days) : " masaaktif
read -p "Limit Speed (contoh 100 untuk 100Mbps) : " LIMIT_INPUT
read -p "Limit IP / Device (contoh 2 untuk 2 device) [2]: " LIMIT_IP
hariini=`date -d "0 days" +"%Y-%m-%d"`
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
clear
if [ "$LIMIT_INPUT" -ge 1000 ]; then
  LIMIT_MB=$(($LIMIT_INPUT / 100))
else
  LIMIT_MB=$LIMIT_INPUT
fi
if [ -z "$LIMIT_MB" ]; then LIMIT_MB=100; fi
if [ -z "$LIMIT_IP" ]; then LIMIT_IP=2; fi
cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF
VPN_PASSWORD_ENC=$(openssl passwd -1 "$VPN_PASSWORD")
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD_ENC:xauth-psk
EOF
mkdir -p /etc/ppp/limits
echo "$VPN_USER:$LIMIT_MB" >> /etc/ppp/limits/bw.conf
echo "$VPN_USER:$LIMIT_IP" >> /etc/ppp/limits/ip.conf
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
echo -e "### $VPN_USER $exp $LIMIT_MB $LIMIT_IP">>"/var/lib/crot/data-user-l2tp"
cat <<EOF

L2TP/IPSEC PSK VPN

IP/Host    : $PUBLIC_IP
Domain     : $domain
IPsec PSK  : myvpn
Username   : $VPN_USER
Password   : $VPN_PASSWORD
Limit      : ${LIMIT_MB}Mbps (input ${LIMIT_INPUT})
Limit IP   : ${LIMIT_IP} Device
Created    : $hariini
Expired    : $exp
EOF
