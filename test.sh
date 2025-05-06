#!/bin/sh 
echo Testing Linux compatibility... 
if [ -f "/app/lib/common.sh" ]; then 
  echo "[OK] Found common.sh in Linux container" 
else 
  echo "[ERROR] Missing common.sh in Linux container" 
  exit 1 
fi 
