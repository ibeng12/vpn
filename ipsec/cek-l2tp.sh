#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DATA="/var/lib/crot/data-user-l2tp"
BW_FILE="/etc/ppp/limits/bw.conf"
mkdir -p /tmp/l2tp_traffic /var/run/l2tp-active

format_mbps() {
  local B=$1; [ $B -lt 0 ] && B=0
  awk "BEGIN {printf \"%7.2f Mbps\", $B*8/1024/1024}"
}

clear
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  CEK L2TP REALTIME - Mbps${NC}"
echo -e "${CYAN}========================================${NC}"
printf "%-10s %-12s %-7s %-10s %-13s %-13s\n" "USER" "EXP" "LIMIT" "STATUS" "DOWN" "UP"
echo "--------------------------------------------------------------------------------"

mapfile -t USERS < <(grep "^###" "$DATA")
for i in "${!USERS[@]}"; do
  line="${USERS[$i]}"
  USER=$(echo $line | awk '{print $2}')
  EXP=$(echo $line | awk '{print $3}')
  LIMIT=$(grep "^$USER:" $BW_FILE 2>/dev/null | cut -d: -f2 | tail -1); [ -z "$LIMIT" ] && LIMIT="50"
  printf "%-10s %-12s %-7s ${RED}%-10s${NC} %-13s %-13s\n" "$USER" "$EXP" "${LIMIT}M" "OFFLINE" "-" "-"
done

TOTAL=${#USERS[@]}

while true; do
  for idx in "${!USERS[@]}"; do
    line="${USERS[$idx]}"
    USER=$(echo $line | awk '{print $2}')
    ROW=$((5 + idx))
    
    # FIX: cari file USER_* atau USER
    IFACE=""
    if ls /var/run/l2tp-active/${USER}_* 1>/dev/null 2>&1; then
      IFACE=$(cat /var/run/l2tp-active/${USER}_* 2>/dev/null | head -1)
    elif [ -f "/var/run/l2tp-active/$USER" ]; then
      IFACE=$(cat /var/run/l2tp-active/$USER)
    fi

    if [ -n "$IFACE" ] && [ -d "/sys/class/net/$IFACE" ]; then
      RX_NOW=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
      TX_NOW=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
      LAST_FILE="/tmp/l2tp_traffic/$IFACE"
      if [ -f "$LAST_FILE" ]; then
        read LR LT < $LAST_FILE
        DRX=$((RX_NOW - LR)); DTX=$((TX_NOW - LT))
        [ $DRX -lt 0 ] && DRX=0; [ $DTX -lt 0 ] && DTX=0
      else DRX=0; DTX=0; fi
      echo "$RX_NOW $TX_NOW" > $LAST_FILE
      SRX=$(format_mbps $DRX)
      STX=$(format_mbps $DTX)
      tput cup $ROW 31
      printf "${GREEN}%-10s${NC} %-13s %-13s   " "AKTIF" "$SRX" "$STX"
    else
      tput cup $ROW 31
      printf "${RED}%-10s${NC} %-13s %-13s   " "OFFLINE" "-" "-"
    fi
  done
  tput cup $((5 + TOTAL + 1)) 0
  echo -ne "Total: $TOTAL | Aktif: $(ls /var/run/l2tp-active/ 2>/dev/null | wc -l) | $(date +%H:%M:%S)   "
  sleep 1
done
