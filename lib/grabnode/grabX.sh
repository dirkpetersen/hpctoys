#!/bin/bash

if [[ -e /app/bin/grabnode ]]; then
  /app/bin/grabnode
  exit
fi

me=$(basename $0)
shell="bash"
cpu=0
partition="exacloud"
cpulimit=44
coresalloc=0
gtype="grab"
cmdline=""
mempercore=16
maxdays=2
gpuopt="--gres=gpu"
username=$(id -nu)

find_grabbed_node()
{
    format="\"%R %.10i %.10j %.2t %.10M %C\""
    sq="squeue -S+i -o $format -u ${username} |grep ${gtype} | grep ' R '"
    grabbed=$(eval $sq)
    if ! [[ -z $grabbed ]]; then
        echo "Nodes already grabbed:"
        args=($grabbed)
        length=${#args[@]} 
        for (( i = 0; i < $length; i++ )); do 
            [[ $(( $i % 6 )) -eq 0 ]] && echo -n ${args[$i]}
            if [[ $(( $i % 6 )) -eq 5 ]]; then
                coresalloc=$(( $coresalloc + ${args[$i]} ))
                echo "  cores: " ${args[$i]}
            fi
        done
    fi
}

# prompt for CPU/cores
read -p "How many CPUs/cores would you like to grab on the node? [1-${cpulimit}] " cpu
# is $cpu numeric ?
if ! [[ $cpu =~ ^[0-9]+$ ]]; then
    echo "Pick a number in the range [1-${cpulimit}]"
    exit
elif [[ $cpu -lt 1 || $cpu -gt ${cpulimit} ]]; then
    echo "Pick a number in the range [1-${cpulimit}]"
    exit
fi

# check for existing grabnode 
find_grabbed_node
if [[ -n "$grabbed" ]]; then 
    total=$(($coresalloc + $cpu))
    echo "total: $total"
    if [[ $total -gt $cpulimit ]]; then
        echo "You can only allocate ${cpulimit} cores with grabnode- "
        echo "you already have $coresalloc cores allocated. Please use a"
        echo "different mechanism to utilize more cores (srun, salloc,"
        echo "or sbatch)"
        exit
    fi
fi

# prompt for Memory
defmem=$(($cpu*$mempercore))
read -p "How much memory (GB) would you like to grab? [${defmem}] " mem
if [[ -z $mem ]]; then
    mem=$defmem
fi
if ! [[ $mem =~ ^[0-9]+$ ]]; then
    echo "Choose a memory size (G) from [1-750]"
    exit
fi
if [[ $mem -gt 750 ]]; then 
    echo "Maximum 750GB memory supported."
    exit  
fi

# prompt user for wall time
#echo -e "\nYou need to enter the maximum number of days this job may run."
echo -n "Please enter the max number of days you would like to grab this node: [1-${maxdays}] "
read days
if [[ -z $days ]]; then
  days=1
elif ! [[ $days =~ ^[0-9]+$ ]]; then
    echo "Supplied Input '$days' is not an Integer."
    exit
fi

# check if a GPU is needed in largenode partition
read -r -p "Do you need a GPU ? [y/N]" response
response=${response,,} # tolower
if [[ $response =~ ^(no|n| ) ]] || [[ -z $response ]]; then
  gpuopt=''  
fi
gpuopt=''
if [[ -z ${gpuopt} ]]; then 
   partition='gpu'
fi

echo -e "\nYou have requested $cpu CPUs on this node/server for $days days or until you type exit."
echo -e "You have decided to share this node/server with other users, THANKS !!!\n"
echo -e "Please DO NOT USE more than $cpu cores at the same time on this node/server."
#echo -e "Use the environment var '\${SLURM_JOB_CPUS_PER_NODE}' to get the # of cores for your job."

echo -e "\nWarning: If you exit this shell before your jobs are finished, your jobs"
echo -e "on this node/server will be terminated. Please use sbatch for larger jobs.\n"
echo -e "Shared PI folders can be found in: /home/groups/ and /home/exacloud/gscratch.\n"

echo Requesting Queue: ${partition} cores: ${cpu} memory: ${mem}
#  Allocate node
#salloc -c ${cpu} --mem=${mem}G -p ${partition} -J ${me} -t "${days}-0" ${gpuopt} $@ sshgrabbed

srun --pty -c ${cpu} --mem=${mem}G -p ${partition} -J ${me} -t "${days}-0" ${gpuopt} $@ ${shell}
