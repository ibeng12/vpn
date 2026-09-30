#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DATA="/var/lib/crot/data-user-l2tp"
BW_FILE="/etc/ppp/limits/bw.conf"
IP_FILE="/etc/ppp/limits/ip.conf"
mkdir -p /tmp/l2tp_traffic /var/run/l2tp-active
NET_IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
[ -z "$NET_IFACE" ] && NET_IFACE="eth0"

format_mbps(){ awk -v b=$1 'BEGIN{printf "%.2f Mbps", b*8/1024/1024}'; }
format_gb(){ awk -v b=$1 'BEGIN{printf "%.2f GB", b/1024/1024/1024}'; }

clear
echo -e "${CYAN}=== CEK L2TP AKURAT (DIAM) ===${NC}"
echo -e "IFACE: $NET_IFACE"
echo -e "RAM  : loading..."
echo -e "VPS SPEED: loading..."
echo -e "TOTAL BW : loading..."
echo -e "${CYAN}---------------------------------------------------------------${NC}"
printf "%-10s %-11s %-5s %-4s %-8s %-12s %-12s\n" "USER" "EXP" "LIM" "IP" "STATUS" "DOWN" "UP"
echo "---------------------------------------------------------------"
mapfile -t USERS < <(grep "^###" "$DATA" 2>/dev/null)
for i in "${!USERS[@]}"; do
  line="${USERS[$i]}"
  USER=$(echo $line | awk '{print $2}')
  EXP=$(echo $line | awk '{print $3}')
  LIM=$(grep "^$USER:" $BW_FILE 2>/dev/null | cut -d: -f2 | tail -1); [ -z "$LIM" ] && LIM=50
  IPLIM=$(grep "^$USER:" $IP_FILE 2>/dev/null | cut -d: -f2 | tail -1); [ -z "$IPLIM" ] && IPLIM=2
  printf "%-10s %-11s %-5s %-4s %-8s %-12s %-12s\n" "$USER" "$EXP" "${LIM}M" "$IPLIM" "OFFLINE" "-" "-"
done

LAST_RX=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
LAST_TX=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)
HEADER=8

while true; do
  RX_NOW=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
  TX_NOW=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)
  VPS_D=$(format_mbps $((RX_NOW - LAST_RX)))
  VPS_U=$(format_mbps $((TX_NOW - LAST_TX)))
  RX_GB=$(format_gb $RX_NOW)
  TX_GB=$(format_gb $TX_NOW)
  LAST_RX=$RX_NOW; LAST_TX=$TX_NOW

  tput cup 1 0; echo -e "IFACE: $NET_IFACE \033[K"
  tput cup 2 0; echo -e "RAM  : $(free -m | awk '/Mem:/ {print $3"/"$2"MB ("int($3*100/$2)"%)"}') \033[K"
  tput cup 3 0; echo -e "VPS SPEED: ${GREEN}↓ $VPS_D${NC} | ${YELLOW}↑ $VPS_U${NC} \033[K"
  tput cup 4 0; echo -e "TOTAL BW : RX $RX_GB | TX $TX_GB \033[K"

  for idx in "${!USERS[@]}"; do
    line="${USERS[$idx]}"
    USER=$(echo $line | awk '{print $2}')
    ROW=$((HEADER + idx))
    IFACE=$(cat /var/run/l2tp-active/$USER 2>/dev/null)
    [ -z "$IFACE" ] && IFACE=$(ls /var/run/l2tp-active/${USER}_* 2>/dev/null | head -1 | xargs cat 2>/dev/null)
    if [ -n "$IFACE" ] && [ -d /sys/class/net/$IFACE ]; then
      RXU=$(cat /sys/class/net/$IFACE/statistics/rx_bytes); TXU=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
      F=/tmp/l2tp_traffic/$IFACE
      if [ -f $F ]; then read LR LT < $F; DRX=$((RXU-LR)); DTX=$((TXU-LT)); else DRX=0; DTX=0; fi
      echo "$RXU $TXU" > $F
      tput cup $ROW 33; printf "${GREEN}AKTIF  ${NC} %-12s %-12s\033[K" "$(format_mbps $DRX)" "$(format_mbps $DTX)"
    else
      tput cup $ROW 33; printf "${RED}OFFLINE${NC} %-12s %-12s\033[K" "-" "-"
    fi
  done
  sleep 1
done
