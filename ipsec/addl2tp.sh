#!/bin/bash
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
read -p "Limit Speed (Mbps, default 50) : " LIMIT_MB
[ -z "$LIMIT_MB" ] && LIMIT_MB=50
hariini=`date -d "0 days" +"%Y-%m-%d"`
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
clear
cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF
VPN_PASSWORD_ENC=$(openssl passwd -1 "$VPN_PASSWORD")
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD_ENC:xauth-psk
EOF
mkdir -p /etc/ppp/limits
echo "$VPN_USER:$LIMIT_MB" >> /etc/ppp/limits/bw.conf
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
echo -e "### $VPN_USER $exp $VPN_PASSWORD $LIMIT_MB">>"/var/lib/crot/data-user-l2tp"
cat <<EOF

L2TP/IPSEC PSK VPN
IP/Host    : $PUBLIC_IP
Domain     : $domain
IPsec PSK  : myvpn
Username   : $VPN_USER
Password   : $VPN_PASSWORD
Limit      : ${LIMIT_MB} Mbps
Created    : $hariini
Expired    : $exp
Script Mod By SL + BW
EOF
