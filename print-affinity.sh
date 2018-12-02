#!/bin/bash
echo "Affinity: `hostname`: $PMIX_RANK  `taskset -pc $$` GPUinfo: $(nvidia-smi --query-gpu=index,uuid --format=csv,noheader )"
