#!/usr/bin/env bash

for host in z8 gx10 v100-2 v100-1 vivobook 3x-v100; do
  echo "== $host =="
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
    'hostname && nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || echo "geen nvidia-smi"'
  echo
done
