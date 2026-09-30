#!/bin/bash
# SL MOD + BW LIMIT + IP LIMIT - FIXED
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
read -p "Limit Speed (Mbps, contoh 100) [100]: " LIMIT_INPUT
read -p "Limit IP / Device (contoh 2) [2]: " LIMIT_IP
hariini=`date -d "0 days" +"%Y-%m-%d"`
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
clear

# FIX: gak perlu bagi 100, apa yang diinput = itu Mbps nya
if [ -z "$LIMIT_INPUT" ]; then LIMIT_INPUT=100; fi
LIMIT_MB=$LIMIT_INPUT
if [ -z "$LIMIT_IP" ]; then LIMIT_IP=2; fi

# validasi angka
if ! [[ "$LIMIT_MB" =~ ^[0-9]+$ ]]; then LIMIT_MB=100; fi
if ! [[ "$LIMIT_IP" =~ ^[0-9]+$ ]]; then LIMIT_IP=2; fi

cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF
VPN_PASSWORD_ENC=$(openssl passwd -1 "$VPN_PASSWORD")
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD_ENC:xauth-psk
EOF
mkdir -p /etc/ppp/limits
# hapus entry lama kalau ada (biar gak dobel)
sed -i "/^$VPN_USER:/d" /etc/ppp/limits/bw.conf
sed -i "/^$VPN_USER:/d" /etc/ppp/limits/ip.conf
echo "$VPN_USER:$LIMIT_MB" >> /etc/ppp/limits/bw.conf
echo "$VPN_USER:$LIMIT_IP" >> /etc/ppp/limits/ip.conf
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
# format baru: ### USER EXP MB IP
sed -i "/^### $VPN_USER /d" /var/lib/crot/data-user-l2tp
echo -e "### $VPN_USER $exp $LIMIT_MB $LIMIT_IP">>"/var/lib/crot/data-user-l2tp"
cat <<EOF

L2TP/IPSEC PSK VPN

IP/Host    : $PUBLIC_IP
Domain     : $domain
IPsec PSK  : myvpn
Username   : $VPN_USER
Password   : $VPN_PASSWORD
Limit      : ${LIMIT_MB} Mbps
Limit IP   : ${LIMIT_IP} Device
Created    : $hariini
Expired    : $exp

EOF
