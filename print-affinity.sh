#!/bin/bash
#echo "Affinity: `hostname`: $PMIX_RANK  `taskset -pc $$` GPUinfo: $(nvidia-smi --query-gpu=index,uuid --format=csv,noheader )"

echo "rank: $PMIX_RANK bound to logical cores `taskset -pc $$` on `hostname` GPUinfo: $(nvidia-smi --query-gpu=index,uuid --format=csv,noheader )"
