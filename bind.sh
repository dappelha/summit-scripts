#!/bin/bash

#--------------------------------------------------------------------------------
# mpirun --bind-to none --np ${nmpi}  bind.sh  your.exe [args]
# You must set env variable RANKS_PER_NODE in your job script;
# optionally set BIND_SLOTS in your job script = #hwthreads per rank.
# Set USE_GOMP=yes to get proper binding for GNU and PGI OpenMP runtimes.
#--------------------------------------------------------------------------------


# This script is for use when using only mpirun (no jsrun binding) 
# it has two purposes:

# 1. Bind your mpi tasks and omp threads to the correct cores

# 2. GPU direct enablement and device binding. Set CUDA visible 
# devices such that each rank has the correct and unique first gpu id
# and all the other devices are also visible 

# Assumptions: all 6 gpus are visible or given to the application. 

# Required Exports by the User:

# RANKS_PER_NODE
# RANKS_PER_GPU

# Optional exports:

# PROFILE_RANK --RUN NVPROF ON THIS RANK, OTHER RANKS RUN NORMAL
# BIND_SLOTS -- cpus per rank, default divides cpus per node by ranks
# OMP_NUM_THREADS -- default is cpus_per_rank
# USE_GOMP=yes -- OpenMP thread placement using GOMP (PGI or GNU) instead of OMP_PLACES.


cpus_per_node=160
# cpu number for each socket:
declare -a list0=(`seq 0 79`)
declare -a list1=(`seq 80 159`)


if [ -z "$PMIX_RANK" ]; then
  echo binding script error : PMIX_RANK is not set ... exiting
fi

let world_rank=$PMIX_RANK

if [ -z "$RANKS_PER_NODE" ]; then
  if [ $world_rank = 0 ]; then
    echo binding script error : you must set RANKS_PER_NODE ... exiting
  fi
  exit
fi


let local_size=$RANKS_PER_NODE
let local_rank=$(expr $world_rank % $local_size)



# divide available slots evenly or specify slots by env variable
if [ -z "$BIND_SLOTS" ]; then
  let cpus_per_rank=$cpus_per_node/$local_size
else
  let cpus_per_rank=$BIND_SLOTS 
fi

if [ -z "$OMP_NUM_THREADS" ]; then
  let num_threads=$cpus_per_rank
else
  let num_threads=$OMP_NUM_THREADS
fi

# BIND_STRIDE is used in OMP_PLACES ... it will be 1 if OMP_NUM_THREADS was not set
let BIND_STRIDE=$(expr $cpus_per_rank / $num_threads)
#echo BIND_STRIDE = $BIND_STRIDE



#-------------------------------------------------
# assign socket and affinity mask
#-------------------------------------------------
let x2rank=2*$local_rank
let socket=$x2rank/$local_size
let ranks_per_socket=$local_size/2

if [ $socket = 0 ]; then
  let ndx=$local_rank*$cpus_per_rank
  let start_cpu=${list0[$ndx]}
  let stop_cpu=$start_cpu+$cpus_per_rank-1
else
  let rank_in_socket=$local_rank-$ranks_per_socket
  let ndx=$rank_in_socket*$cpus_per_rank
  let start_cpu=${list1[$ndx]}
  let stop_cpu=$start_cpu+$cpus_per_rank-1
fi

#---------------------------------------------
# set OMP_PLACES or GOMP_CPU_AFFINITY
#---------------------------------------------
if [ "$USE_GOMP" == "yes" ]; then
  export GOMP_CPU_AFFINITY="$start_cpu-$stop_cpu:$BIND_STRIDE"
  unset OMP_PLACES
else
  export OMP_PLACES={$start_cpu:$num_threads:$BIND_STRIDE}
fi

#-------------------------------------------------
# create "command" which binds tasks for each rank using taskset
#-------------------------------------------------
printf -v command "taskset -c %d-%d"  $start_cpu  $stop_cpu 
#echo command = $command





#------- GPU direct CUDA Visible Devices setup ---------------

echo "Original CUDA visible devices:"
echo $CUDA_VISIBLE_DEVICES
echo "forcing 4 gpu CUDA visible devices:"
export CUDA_VISIBLE_DEVICES=0,1,2,3


# set up different default device depending on rank:

world_rank=$PMIX_RANK
let local_size=$RANKS_PER_NODE
let local_rank=$(expr $world_rank % $local_size)
#let num_devices_socket=$(nvidia-smi -L | grep -c GPU)

# check for correct inputs:
if [ -z $RANKS_PER_GPU ]; then
    echo "you must export RANKS_PER_GPU...exiting"
    exit
fi

# index for picking from CUDA visible devices
let indx=$local_rank/$RANKS_PER_GPU

let indx=$indx+1

device=$(awk -F, '{print $'"$indx"'}' <<<  $CUDA_VISIBLE_DEVICES)

visible_devices=$CUDA_VISIBLE_DEVICES

CUDA_VISIBLE_DEVICES="${device},${visible_devices}"

# Process with sed to remove the duplicate and reform the list, keeping the order we set

CUDA_VISIBLE_DEVICES=$(sed -r ':a; s/\b([[:alnum:]]+)\b(.*)\b\1\b/\1\2/g; ta; s/(,,)+/,/g; s/, *$//' <<< $CUDA_VISIBLE_DEVICES)
export CUDA_VISIBLE_DEVICES

echo "Updated CUDA visible devices:"
echo $CUDA_VISIBLE_DEVICES

#---------End GPU Direct setup -----------------------------



#Launch the application that followed this binding script:

if [ "$PMIX_RANK" == "$PROFILE_RANK" ]; then
    #    nvprof --profile-from-start off -f -o $PROFILE_PATH "$@"
    $command nvprof -s "$@"
else
    $command "$@"
fi
