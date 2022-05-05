#!/bin/bash

# modified for Ubuntu 12.04, dp 2012-04-27
# added grablargenode, ers 2012-08-27
# overhaul,consolidated into single grabX.sh, dp 2017-05-16

# 2018.02.07 John Dey jfdey@fredhutch.org
# - check cpu count after allocation; condition of using more than 28 cores
# - exit from ssh salloc; condition of reattaching to other session
# - reduce code by 60%, 
# - only use grabnode interface [remove grab4, grab6 etc]
# - validate user input

# 2019.07.13 petersen 
# - added GPU option and passing through command line salloc

me=$(basename $0)
shell="bash"
cpu=0
partition="campus-new"
cpulimit=36
coresalloc=0
gtype="grab"
cmdline=""
mempercore=20
maxdays=7
gpuopt="--gres=gpu"
username=$(id -nu)

kinit -R
retcode=$?
if ! [[ $retcode = 0 ]]; then
    #echo "kinit error: $retcode"
    echo "Please type 'kinit<enter>' to get a new kerberos login ticket. Then try again."
    exit
fi

case "$me" in
    grabnode)
        ;;        
    rstudiograb | grabRstudio | grabR)
        echo -e "The grab commands for R and rstudio have been discontinued."
        echo -e "Please use a command such as 'grabfullnode' and then start R/rstudio"
        exit
        ;;        
    *)
        echo -e "Please use grabnode, all other variations of grabnode have been discontinued."
        exit
        ;;
esac

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
elif [[ $cpu -lt 1 || $cpu -gt 36 ]]; then
    echo "Pick a number in the range [1-${cpulimit}]"
    exit
fi
#if [[ $cpu -le 4 ]]; then
#  maxdays=30
#fi
#if [[ $cpu -gt 4 ]]; then
#  partition="largenode"
#fi
#if [[ $cpu -gt 4 && $cpu -lt 6 ]]; then 
#    echo "WARNING: $cpu cores unsupported on any partition- increasing to 6"
#    cpu=6
#fi


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
if [[ $mem -gt 21 && $cpu -ge 6 ]]; then
    #partition="largenode"
    maxdays=7
fi
if [[ $mem -lt 21 && $cpu -ge 6 ]]; then 
    #echo "WARNING: memory request ($mem) too low- increasing to minimum (21 GB)"
    mem=21
    #partition="largenode"
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

# largenode jobs are not 30 days
if [[ $days -gt 7 && ${partition} == "largenode" ]]; then
  echo -e "\nlargenode jobs are limited to 7 days."
  exit
fi

# check if a GPU is needed in largenode partition
if [[ "$partition" == "campus-new" ]]; then
  read -r -p "Do you need a GPU ? [y/N]" response
  response=${response,,} # tolower
  if [[ $response =~ ^(no|n| ) ]] || [[ -z $response ]]; then
    gpuopt=''  
  fi
else
  gpuopt=''
fi


echo -e "\nYou have requested $cpu CPUs on this node/server for $days days or until you type exit."
echo -e "You have decided to share this node/server with other users, THANKS !!!\n"
echo -e "Please DO NOT USE more than $cpu cores at the same time on this node/server."
#echo -e "Use the environment var '\${SLURM_JOB_CPUS_PER_NODE}' to get the # of cores for your job."

echo -e "\nWarning: If you exit this shell before your jobs are finished, your jobs"
echo -e "on this node/server will be terminated. Please use sbatch for larger jobs.\n"
echo -e "Shared PI folders can be found in: /fh/fast, /fh/scratch and /fh/secure.\n"

echo Requesting Queue: ${partition} cores: ${cpu} memory: ${mem}
#  Allocate node
salloc -c ${cpu} --mem=${mem}G -p ${partition} -J ${me} -t "${days}-0" ${gpuopt} $@ sshgrabbed
