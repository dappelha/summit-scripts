#!/bin/bash

# Example setup for running jsrun with 1 rank per GPU on Summit.
# This script creates a batch.job file and submits it to the que.
# It is best to edit this file, never the batch.job file.

# user specified:
nodes=1
gpus_per_socket=3 # number of gpus to use per socket ( 3 for summit, 2 for sierra)
gpus_per_rs=1 # 1 res set per GPU (one to one gpu to rs mapping).
threads_per_core=2 # Each core can go up to smt4 for 4 hardware threads.
ranks_per_rs=1 # If using more than 1 rank per gpu, need to enable  mps through lsf.

# derived quantities:
let rs_per_socket=$gpus_per_socket/$gpus_per_rs
let ranks_per_socket=$ranks_per_rs*$rs_per_socket
# There are 21 (of 22) cores available to the application per socket (on Summit)
let cores_per_rank=21/$ranks_per_socket # 21 avail cores divided into the ranks.
let cores_per_rs=$cores_per_rank*$ranks_per_rs
let nmpi=2*$ranks_per_socket*$nodes  # total number of mpi ranks
let nrs=2*$rs_per_socket*$nodes # total number of resource sets:
let threads_per_rank=$threads_per_core*$cores_per_rank

echo "nodes = $nodes"
echo "gpus used per socket = $gpus_per_socket"
echo "ranks_per_socket = $ranks_per_socket"
echo "cores_per_rank = $cores_per_rank"
echo "threads per rank = $threads_per_rank"

#-----This part creates a submission script---------
cat >batch.job <<EOF
#BSUB -o %J.out
#BSUB -e %J.err
#BSUB -nnodes ${nodes}
##BSUB -alloc_flags gpumps
#BSUB -alloc_flags smt2
#BSUB -P VEN201
#BSUB -q batch
#BSUB -W 5
#---------------------------------------

ulimit -s 10240

export OMP_NUM_THREADS=$threads_per_rank

export OMPI_LD_PRELOAD_POSTPEND=/ccs/home/walkup/mpitrace/spectrum_mpi/libmpitrace.so

export OMP_STACKSIZE=64M
export PAMI_ENABLE_STRIPING=1

echo 'starting jsrun with'
echo "nodes = $nodes"
echo "gpus used per socket = $gpus_per_socket"
echo "ranks_per_socket = $ranks_per_socket"
echo "cores_per_rank = $cores_per_rank"
echo "threads per rank = $threads_per_rank"

jsrun --stdio_mode=prepend -D CUDA_VISIBLE_DEVICES \
      -E OMP_NUM_THREADS=${threads_per_rank} \
      --nrs ${nrs}  --tasks_per_rs ${ranks_per_rs} \
      --cpu_per_rs ${cores_per_rs} \
      --gpu_per_rs ${gpus_per_rs} \
      --bind=proportional-packed:${cores_per_rank} \
      -d plane:${ranks_per_rs}  \
      ./print-affinity.sh


EOF
#-----This part submits the script you just created--------------
bsub  batch.job
