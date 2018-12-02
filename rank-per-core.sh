#!/bin/bash


# Example setup for running jsrun with 1 rank per core on Summit.
# This script creates a batch.job file and submits it to the que.
# It is best to edit this file, never the batch.job file.


#input:
nodes=1
gpus_per_socket=3 # number of gpus to use per socket
application_cores=21 # If using core isolation 1, There are 21 (of 22) cores available to the application per socket
threads_per_core=4 # Each core can go up to smt4 for 4 hardware threads.

# user sets rank_per_socket, calculate other quantities from this:
ranks_per_socket=21 # needs to be evenly divisible by gpus_per_socket (if using GPUs)

# calculated from input:
let num_sockets=2*$nodes
let cores_per_rank=$application_cores/$ranks_per_socket # avail cores divided into the ranks.
let cores_per_socket=$cores_per_rank*$ranks_per_socket # this is used cores per socket (not necessarily equal to application cores)
let threads_per_rank=$threads_per_core*$cores_per_rank

# Print sanity check:
echo "nodes = $nodes"
echo "gpus used per socket = $gpus_per_socket"
echo "ranks_per_socket = $ranks_per_socket"
echo "cores_per_rank = $cores_per_rank"
echo "used cores per socket = $cores_per_socket"
echo "threads_per_rank = $threads_per_rank"

#--------------------------------------
cat >batch.job <<EOF
#BSUB -o %J.out
#BSUB -e %J.err
#BSUB -nnodes ${nodes}
##BSUB -alloc_flags gpumps
#BSUB -alloc_flags smt4
#BSUB -P VEN201
#BSUB -q batch
#BSUB -W 5
#---------------------------------------

ulimit -s 10240

export OMP_NUM_THREADS=$threads_per_rank

echo 'starting jsrun with'
echo "nodes = $nodes"
echo "gpus used per socket = $gpus_per_socket"
echo "ranks_per_socket = $ranks_per_socket"
echo "cores_per_rank = $cores_per_rank"
echo "used cores per socket = $cores_per_socket"
echo "threads_per_rank = $threads_per_rank"


# CHECK AFFINITY:

jsrun --stdio_mode=prepend -D CUDA_VISIBLE_DEVICES \
  -E OMP_NUM_THREADS=${threads_per_rank} \
  --nrs ${num_sockets} \
  --tasks_per_rs ${ranks_per_socket} \
  --cpu_per_rs ${cores_per_socket} \
  --gpu_per_rs ${gpus_per_socket} \
  --bind=proportional-packed:${cores_per_rank} \
  -d plane:${ranks_per_socket} \
  ./print-affinity.sh 

EOF
#---------------------------------------
# SUMMIT:
bsub batch.job
