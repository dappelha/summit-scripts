#!/bin/bash
nodes=1
ppn=4
let nmpi=$nodes*$ppn

mympirun=/opt/ibm/spectrum_mpi/bin/mpirun

#--------------------------------------
cat >batch.job <<EOF
#BSUB -o %J.out
#BSUB -e %J.err
#BSUB -R "span[ptile=${ppn}]"
### below is gpu per node
#BSUB -gpu "num=4"
#BSUB -n ${nmpi}
#BSUB -x
#BSUB -q normal
#BSUB -W 30
#BSUB -env "all,LSB_START_JOB_MPS=N"
#---------------------------------------

export OMP_NUM_THREADS=1
export RANKS_PER_NODE=$ppn
export RANKS_PER_GPU=1
export CUDA_VISIBLE_DEVICES=0,1,2,3

${mympirun} --bind-to none -np $nmpi ./bind.sh ./print-affinity.sh

#${mympirun} --map-by socket:PE=10 --rank-by socket -np $nmpi ./print-affinity.sh

#${mympirun} --bind-to socket -np $nmpi ./print-affinity.sh


EOF
#---------------------------------------
bsub <batch.job
