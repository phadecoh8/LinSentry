#!/bin/bash

echo "=========="
echo " Sysytem Hardening Aduit"
echo "=========="
echo ""
echo "Starting checks..."

echo ""
echo "[1] checking open network ports"
echo "_________"
ss -tuln

echo ""
echo "[2] Flagging ports exposed to the outside world"
echo "_________"

RISKY_PORTS=$(ss -tuln | grep -E '0\.0\.0\.0|\[::\]:')

if [ -z "$RIKSY_PORTS" ]; then 
	echo "None Found. All listening ports are local-only (safe)."
else 
	echo "WARNING: The following ports are open to any network device:"
	echo "$RIKSY_PORTS"
fi
