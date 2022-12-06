#! /bin/bash

# hty - HPCToys commands 
#
# notes: 
# Expand with https://starship.rs/
# Also check https://github.com/fasrc for more tools
#
SCR=${0##*/}
SUBCMD=$1
ME=$(whoami)
STARTDIR=$(pwd)
STARTBASE=$(basename ${STARTDIR})
GITMINFILES=1 # number of files in git after blank init

export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
source ${HPCTOYS_ROOT}/etc/profile.d/zzz-hpctoys.sh

htyRootCheck || exit

#initLpython
[[ -n $1 ]] && shift 
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:" OPTION; do
  #echo "OPTION: -${OPTION} ARG: ${OPTARG}"
  eval OPT_${OPTION}=\$OPTARG
done
shift $((OPTIND - 1))

if [[ "${OPT_s}" == "e" ]]; then
  set -e
fi

# ****************

interactive() {

  slurmGetGrabbedNodes
QST=$(cat << EOF
You have already reserved ${INTNUMCORES} CPU cores.  
Do you want to reconnect to your first 
node ${INTNODE} via ssh?
EOF
)
  #echo ${INTNODE}
  if [[ -n "${INTNODE}" && -n "${INTNUMCORES}" ]]; then
    htyDialogYesNo "${QST}" "Re-use your node?"
    if [[ "${RES}" == "Yes" ]]; then 
      ssh ${INTNODE}
      return
    fi
  fi 
  buildjob

  htyEcho "You can also paste this at the top of a script:\n" 
  echo -e "#! /bin/sh"
  echo -e "${SBATCH}"
  echo -e "# module load something\n"  

  CMDLINE="-J '!interactive' -p ${RPART} -t ${RTIME} "
  CMDLINE+="-c ${RCORES} --mem-per-cpu ${RMEM} "
  [ -n "${DEFACCT}" ] && CMDLINE+="--account ${DEFACCT} "
  [ -n "${RQOS}" ] && CMDLINE+="--qos ${RQOS} "
  [ -n "${RGPU}" ] && CMDLINE+="--gres ${RGPU} "
  [ -n "${RDISK}" ] && CMDLINE+="--gres ${RDISK} "
  [ -n "${RFEAT}" ] && CMDLINE+="--constraint ${RFEAT} "
  htyEcho "executing: srun ${CMDLINE} --pty bash\n"
  srun ${CMDLINE} --pty bash
}

slurmGetNodeInfo() {
  local GPART="${1}" 

  # example (A/I/O/T): node-6-15 44 512000 20/24/0/44
  # extract second number from split 4th column and extract second number 

  NODES=$(sinfo --noheader -p "${GPART}" -o "%n %c %m %C" |  
          awk -F " " '{ split($4, AR, "/"); print $1" "$2" "$3" "AR[2]}')

  # maximum cpu cores available on any node
  MAXCORES=$(echo "${NODES}" | sort -k2,2nr |
              head -1 | awk '{print $2}')
  # maximum cpu cores available on any node that are idle right now
  MAXIDLECORES=$(echo "${NODES}" | sort -k4,4nr |
              head -1 | awk '{print $4}') 
  # Max mem on a high cpu core node
  MAXCORESMEM=$(echo "${NODES}" | sort -k2,2nr |
              head -1 | awk '{print $3}')
  # maximum memory available on any node 
  MAXMEM=$(echo "${NODES}" | sort -k3,3nr |
              head -1 | awk '{print $3}')
  # Max CPU cores on a high memory node
  MAXMEMCORES=$(echo "${NODES}" | sort -k3,3nr |
              head -1 | awk '{print $2}')
  # Max CPU cores on a high memory node
  MAXMEMIDLECORES=$(echo "${NODES}" | sort -k3,3nr |
              head -1 | awk '{print $4}')

  #htyEcho "slurmGetNodeInfo: $MAXCORES $MAXIDLECORES $MAXCORESMEM $MAXMEM $MAXMEMCORES $MAXMEMIDLECORES" 0
}

slurmGetGrabbedNodes() {

  # get my running jobs with jobname "!interactive" and 
  # return hostname and # cores as a 2-column table
  IJOBS=$(squeue --noheader -u ${ME} -t R -o "%R|%C|%j" |
         awk -F'|' '{ if ($3=="!interactive") { print $1" "$2 } }'
         )  
  unset INTNUMCORES INTNODE
  if [[ -n $IJOBS ]]; then
    # get the sum of all interactive cores, second column
    INTNUMCORES=$(echo "${IJOBS}" | awk -F' ' '{sum+=$2;}END{print sum;}')
    #INTNUMCORES=$(echo "${IJOBS}" | awk -F' ' '{NR==1{print $2}')
    INTNODE=$(echo "${IJOBS}" | awk -F' ' 'NR==1{print $1}')
  fi

  #htyEcho "INTNUMCORES: ${INTNUMCORES} / INTNODE: ${INTNODE}" 0
}

slurmGetTres() {

TRES=$(sacctmgr --noheader --parsable2 show tres)

#cpu||1
#mem||2
#energy||3
#node||4
#billing||5
#fs|disk|6
#vmem||7
#pages||8
#gres|gpu|1001
#gres|disk|1002


}

slurmSelectGresFeatures() {

  # get advanced info
  #ttps://github.com/OleHolmNielsen/Slurm_tools/blob/master/pestat/pestat

  # Here we will select constraints and gres per partition
  GRES=$(sinfo --noheader -p ${RPART} -o "%G")

  X=$(echo -e "${GRES}" | awk -F "," '{ print $1 }' | sort | uniq)
  Y=$(echo -e "${GRES}" | awk -F "," '{ print $2 }' | sort | uniq)
  Z=$(echo -e "${GRES}" | awk -F "," '{ print $3 }' | sort | uniq)


  unset GPUS DISKS
  for G in $X $Y $Z; do
    #htyEcho "G: $G" 0
    if [[ $G =~ "gpu:" ]]; then
      GPUS+="$G "
    elif [[ $G =~ "disk:" || $G =~ "lscratch:" 
               || $G =~ "scratch:" ]]; then
      DISKS+="$G "
    fi
  done

  # select GPU config 

  if [[ -n "${GPUS}"  ]]; then
    # we have detected GPUs in our GRES
QST=$(cat << EOF
Please select your GPU config. You can pick 
'gpu:none' if you do not need any GPU at all or 
'gpu:any' if you do need a GPU but not require 
a specific GPU model. 
The trailing number indicates how many GPUs you 
can request per node in the next dialog
EOF
)
  else
QST=$(cat << EOF
Could not detect GPUs in partition ${RPART}. 
You can pick 'gpu:none' if you do not need any 
GPU at all or 'gpu:any' if you require a GPU 
and will adjust the partiton information later.
EOF
)
  fi

  GPUS="gpu:none gpu:any ${GPUS}"
  DISKS="disk:none ${DISKS}"

  htyDialogMenu "${QST}" "${GPUS}" "gpu:none" "Select GPU type"
  RGPU=${RES}

  if [[ ${RGPU} == "gpu:none" ]]; then
    RGPU=""
  elif [[ ${RGPU} == "gpu:any" ]]; then
    RGPU="gpu:1"
  fi

  if [[ ${RGPU} == "gpu:1" ]]; then
QST=$(cat << EOF
The trailing number shows how many GPUs you 
are requesting per node. 
[The more you request, the longer it may 
take until your job starts].
EOF
)
  else
QST=$(cat << EOF
The trailing number shows how many GPUs you can
request per model and node. [The more you 
request, the longer it may take until your job
starts].
If you only need a single GPU adjust the trailing
number to 1
EOF
)
  fi

  if [[ -n ${RGPU} ]]; then 
    htyDialogInputbox "${QST}" "${RGPU}" "Confirm number of GPUs"
    RGPU=${RES}
  fi


  #htyEcho "Selected GPU :$RGPU" 0

  ###### ******  GRES for Disk 


QST=$(cat << EOF
Please select the disk config for your job to 
request temporary scratch space on the local 
drive of the compute node.
Please pick the default 'disk:none' if you do 
not need any local scratch space.
EOF
)

  htyDialogMenu "${QST}" "${DISKS}" "disk:none" "Select local disk"
  RDISK=${RES}

  if [[ ${RDISK} == "disk:none" ]]; then
    RDISK=""
  fi

QST=$(cat << EOF
The trailing number shows the maximum disk space 
in GB you can request. [The more you request, 
the longer it may take until your job starts].
If you adjust to 1024 or 1K, you request one TB.
EOF
)

  if [[ -n ${RDISK} ]]; then
    htyDialogInputbox "${QST}" "${RDISK}" "local disk space"
    RDISK=${RES}
  fi

  #### ********  Features **************

  FEATURES=$(sinfo --noheader -p exacloud -o "%f")

  unset LFEAT
  for F in ${FEATURES}; do 
    IFS=','
    for X in $F; do 
      [[ "${X}" == "(null)" ]] && continue
      [[ " ${LFEAT} " =~ " ${X} " ]] || LFEAT+="$X "
    done
    unset IFS
  done 
  LFEAT="None ${LFEAT}"

QST=$(cat << EOF
Some nodes have certain hardware or other 
features that are not available on other nodes.
To ensure that you only run your jobs on nodes
with these features enabled, you can apply a 
--constraint. Please select the features below.
EOF
)
  if [[ -n "${LFEAT}" ]]; then 
    htyDialogChecklist "${QST}" "${LFEAT}" "None" "Select Features/Constraints"
    RFEAT=${RES}
  fi
  RFEAT=${RFEAT// /,}
  RFEAT=${RFEAT/None,/}
  [[ "${RFEAT}" == "None" ]] &&  RFEAT=""
}

slurmSelectPartition() {
  local PARTALLOWED="${1}"; local APARTS=""
  if [[ -z ${PARTALLOWED} ]]; then
    echo "no partitions passed to slurmSelectPartition()"
    return
  fi
  RPART=""
  PARTS=$(sinfo --noheader -o "%.25P[%l]" | xargs)
  PARTS="${PARTS/\*/}"
  PARTS="${PARTS//:00:00/}"
  PARTS="${PARTS//-00]/-0]}"
 
  # reduce PARTS to list of allowed APARTS 
  for X in ${PARTALLOWED}; do
    #echo "X:${X}"  
    for Y in ${PARTS}; do 
      #echo "Y:${Y}"  
      if [[ "${Y}" =~ "${X}" ]]; then
        APARTS+="${Y} "
      fi  
    done 
  done

  #$htyEcho "APARTS: ${APARTS} PARTALLOWED: ${PARTALLOWED}"

QST=$(cat << EOF
Please select one of your allowed partitions.
Note that the default maximum runtime is shown in
[days-hours]. 
If you need to run longer than the default 
maximum you will be asked to select a different 
QOS setting later 
EOF
)

  htyDialogMenu "${QST}" "${APARTS}" "${RPARTLONG}" "Select Partition or Queue"
  RPART=${RES%%[*}
  RPARTLONG=${RES}
  
  #htyEcho "RPART: ${RPART}" 0
}

slurmCheckPartition() {
  local CPART="$1"
  local ACCTS="$2"

  unset IFS

  for C in ${CPART}; do
    eval pt_"${C%%=*}"="${C#*=}"
    #echo "pt_${C%%=*}=${C#*=}"
    if [[ "${pt_Default}" == "YES" ]]; then
      DEFPART="${pt_PartitionName}"
      pt_Default=""
    fi
  done
  #htyEcho "DEFPART summary:${DEFPART}" 0
  if [[ -z ${ACCTS} ]]; then
    # accounts are likely not setup, just return
    return 0
  fi
  #htyEcho "pt_PartitionName: ${pt_PartitionName} Default:${pt_Default} DEFPART: ${DEFPART}" 0
  
  #echoerr "\n ****** PARTITION: ${pt_PartitionName} *********** "

  #pt_PartitionName="exacloud"
  #pt_MaxNodes="12"
  #pt_MaxTime="1-12:00:00"
  #pt_DenyQos="gpu_long_jobs"
  #pt_AllowQos="gpu_long_jobs"
  #pt_DenyAccounts="basic"
  #pt_AllowAccounts="basic"
  #pt_QoS="N/A"
  #pt_AllowGroups="accessexacloud"
  #pt_DenyGroups="accessexacloud"

  # check if account is denied
  # 
  ACC_ALLOW=""
  if [[ -n "${pt_AllowAccounts}" ]]; then
    for X in ${ACCTS}; do
      if [[ "${pt_AllowAccounts}" == "ALL" ]]; then
        #echo "$X is allowed via AllowAccounts: ${pt_AllowAccounts}"
        ACC_ALLOW=1
        break
      elif htyInCsv "${X}" "${pt_AllowAccounts}"; then
        #echo "$X is allowed via AllowAccounts: ${pt_AllowAccounts}"
        ACC_ALLOW=1
        break
      else
        #echo "$X is denied via AllowAccounts: ${pt_AllowAccounts}"
        ACC_ALLOW=0
      fi
    done
  elif [[ -n "${pt_DenyAccounts}" ]]; then
    for X in ${ACCTS}; do
      if htyInCsv "${X}" "${pt_DenyAccounts}"; then
        #echo "$X is denied via DenyAccounts: ${pt_DenyAccounts}"
        ACC_ALLOW=0
      else
        #echo "$X is allowed via DenyAccounts: ${pt_DenyAccounts}"
        ACC_ALLOW=1
        break
      fi
    done
  fi

  # check if Group is allowed
  GRP_ALLOW=""
  IFS=','
  if [[ -n "${pt_AllowGroups}" ]]; then
    for X in ${pt_AllowGroups}; do
      if [[ "${X}" == "ALL" ]]; then
        #echo "$X is allowed via AllowGroups"
        GRP_ALLOW=1
        break
      elif htyInGroup "${X}"; then
	#echo "$X is allowed via AllowGroups"
	GRP_ALLOW=1
        break
      else
        #echo "$X is denied via AllowGroups"
        GRP_ALLOW=0
      fi 
    done
  elif [[ -n "${pt_DenyGroups}" ]]; then
     for X in ${pt_DenyGroups}; do
      if htyInGroup "${X}"; then
        #echo "$X is denied via DenyGroups"
        GRP_ALLOW=0
      else
        #echo "$X is allowed DenyGroups"
        GRP_ALLOW=1
        break
      fi
    done     
  fi
  unset IFS

  if [[ ${ACC_ALLOW} -eq 0 ]]; then
    return 1
  fi  
  if [[ ${GRP_ALLOW} -eq 0 ]]; then
    return 1
  fi  
}

adjustResources() {

  # if needed: adjust number of req CPUs down to max cpu in large mem node
  if [[ ${RCORES} -gt ${MAXMEMCORES} ]]; then
    if [[ $((${RMEM%GB}*${RCORES})) -gt $((${MAXCORESMEM}/1000)) ]]; then
QST=$(cat << EOF
You requested a large amount of memory and a
node with sufficient memory does not have as
many CPU cores as you requested. Your request
has been reduced from ${RCORES} to ${MAXMEMCORES} CPU cores.
EOF
)
      dialog --title "Fewer cores!" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0

      RCORES=${MAXMEMCORES}
      #htyEcho "RCORES ADJUSTED: ${RCORES}" 0
    fi
  fi
}

adjustQOS() {

  if [[ $(htySlurmTime2Sec "${RTIME}") -gt \
        $(htySlurmTime2Sec "${PTMAXTIME[${RPART}]}") ]]; then

    LQOS=$(sacctmgr --noheader show qos \
         format=name%25,maxwall,flags | grep "PartitionTimeLimit")
    LQOS=${LQOS//PartitionTimeLimit/}

    TQOSSTR=""
    IFS=$'\n'
    for X in ${LQOS}; do
      Y="$(echo "$X" | xargs)"
      Z="${Y/:00:00/}"
      TQOSSTR+="${Z/ /[}] "
    done
    unset IFS

    #htyEcho "TQOSSTR ${TQOSSTR}" 0

    if [[ -n ${TQOSSTR} ]]; then 

QST=$(cat << EOF
Please select a QOS with a timelimit >= ${RTIME}.
Longer time limits typically mean that you can
run fewer jobs in parallel.
EOF
)
       htyDialogMenu "${QST}" "${TQOSSTR}" "" "Select a QOS" || exit
       RQOS=${RES%%[*}

       #htyEcho "RQOS: ${RQOS}" 0
     else

QST=$(cat << EOF
No other QOS are configured, falling back to defaults
EOF
)
       dialog --title "No QOS available" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0

     fi

  fi

}

# ###### Entrypoint to Job Builder ######################## 
buildjob() {
  #local RET; local RES; local NODES
  #local PARTS; local WTIMES; local DEFPART
  #local RCORES; local RMEM; local RTIME
  unset SBATCHHEAD RCORES RMEM RTIME RPART

  SBATCH=''
  SEMAIL='name@org.edu'
  if htyInPath git; then
    SEMAIL=$(git config --global user.email)
  fi

  if ! htyInPath "sacctmgr"; then

QST=$(cat << EOF
Slurm does not seem to be installed on this
System (could not find sacctmgr). 
Please try again on a system that has Slurm
installed.
EOF
)
    dialog --title "Slurm not found!" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0
    exit 1

#    SBATCH+="#SBATCH --job-name=MyJob\n"
#    SBATCH+="#SBATCH --nodes=1 --ntasks=1\n"
#    SBATCH+="#SBATCH --cpus-per-task=1\n"
#    SBATCH+="#SBATCH --mem-per-cpu=1G\n"
#    SBATCH+="#SBATCH --time=1-00:00:00\n"
#    SBATCH+="#SBATCH --output=MyJob_%A_%a.out\n"
#    SBATCH+="#SBATCH --error=MyJob_%A_%a.err\n"
#    SBATCH+="#SBATCH --array=1-1%1                 # %13 = run 13 jobs in parallel\n"
#    SBATCH+="#SBATCH --mail-type=FAIL,END          # or NONE/ALL or BEGIN,FAIL,END\n"
#    SBATCH+="#SBATCH --mail-user=${SEMAIL}\n"
#    SBATCH=${SBATCH::-2} # strip final new line
#    return 0
  fi

  #htyEcho $SBATCH 0

  # get partitions with configs from Slurm
  ALLPARTS=$(scontrol show partition --oneliner)

  MYRET=$?
  if [[ ${MYRET} -gt 0 ]]; then  
    htyEcho "Slurm returned error ${MYRET}" 
    htyEcho "Please run this tool on a functioning HPC system" 0
    exit 1
  fi

  # get my account and QOS info from Slurm
  MYACCQOS=$(sacctmgr --noheader show associations \
             where user="${ME}"  format=account%25,qos%256)

  DEFACCT=$(sacctmgr --noheader show user where \
             user=${ME} format=DefaultAccount | xargs)

  MYACCTS='' # a list of my accounts
  declare -A MYQOS # a dict of account qos associations

  IFS=$'\n'
  for X in ${MYACCQOS}; do
    Y="$(echo "$X" | xargs)"
    Z=${Y%% *}
    MYACCTS+="${Z} "
    MYQOS[$Z]="${Y#* }"
  done
  unset IFS

  # default partition is retrieved in slurmCheckPartition
  DEFPART=""
  declare -A PTMAXTIME
  IFS=$'\n'
  #echoerr " ** MYACCTS: ${MYACCTS}"
  for X in ${ALLPARTS}; do 
    #echoerr "${X}"
    unset IFS
    if slurmCheckPartition "${X}" "${MYACCTS}"; then
      MYPARTS+="${pt_PartitionName} "
      PTMAXTIME[${pt_PartitionName}]=${pt_MaxTime}
    fi
    IFS=$'\n'
  done
  unset IFS 

  #MYPARTS='basic'
  if htyInList "${DEFPART}" "${MYPARTS}"; then
    # you have access to the default partion 
    # Set it to requested pertition and check again
    RPART="${DEFPART}"
  elif [[ $(wc -w <<< "${MYPARTS}") -eq 1 ]]; then 
    # you only have access to one partition, use it
    RPART="${MYPARTS}"
  else
    # prompt for different partion based on MYPARTS
    slurmSelectPartition "${MYPARTS}"
    # and return RPART
    #echo "MY ALLOWED PARTITIONS: ${MYPARTS}"
  fi

  slurmGetNodeInfo "${RPART}"  

  #htyEcho "PTMAXTIME: ${PTMAXTIME[${RPART}]}, RPART: ${RPART}" 0

QST=$(cat << EOF
How many CPU cores are you requesting per node or
task? The largest node has ${MAXCORES} cpu cores installed 
and right now at least one node has ${MAXIDLECORES} free CPU cores 
available to start a job immediatelty.
For job arrays you will request 1-2 CPU cores per  
task in most cases.
EOF
)

  htyDialogInputbox "${QST}" "1" \
      "How many CPU cores? (${MAXIDLECORES})" || exit
  RCORES=${RES}

  if [[ ${RCORES} -gt ${MAXCORES} ]]; then  

QST=$(cat << EOF
You requested more cores than the largest 
machine has available. Please start again 
and request not more than ${MAXCORES} cores.
EOF
)
    dialog --title "Fewer cores!" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0
    
    exit
  fi
  
  #htyEcho "Cores: ${RES}" 0 

QST=$(cat << EOF
How much memory per core are you requesting?
4GB is a fairly typical choice but you can do 
more or less. NOTE: This is GB per CPU core and
if you request 4 cores and 4GB per core you will
get a node with at least 16GB free memory.
EOF
)

  MAXMEMCORE=$((${MAXMEM}/1024/${RCORES}))
  MEMS=""
  #echo "MAXMEMCORE: ${MAXMEMCORE}"
  for G in 1 2 4 8 16 32 64 128 256 384 512 768 1024; do
    if [[ $G -le ${MAXMEMCORE} ]]; then
      MEMS+="${G}-GB "      
    fi
  done
  #echo "MEMS: ${MEMS}"
  htyDialogMenu "${QST}" "${MEMS}" "4-GB" "How much memory per core?" || exit
  RMEM="${RES%%-*}GB"

  #htyEcho "Mem: ${RMEM}" 0

  # if needed: adjust number of req CPUs down to max cpu in large mem node 
  adjustResources

  #htyEcho "PTMAXTIME: ${PTMAXTIME[${RPART}]}, RPART: ${RPART}" 0

QST=$(cat << EOF
How long will your job run [days-hours]? 
For example, if your job requires 2 days, enter 
'2-0' and if it wants 3 hours, enter '0-3' but
if it only needs 15 min, just enter '15'.
The maximum time for partition "${RPART}" 
is ${PTMAXTIME[${RPART}]}. 
If you enter a longer time you will be prompted
for a so called QOS which will allow you to run 
longer but with fewer resources. 
EOF
)

  htyDialogInputbox "${QST}" "1-0" "Job run time?" || exit
  RTIME=${RES}
  #htyEcho "RTIME ${RTIME}" 0

  # If Partition Time limit is too short we need to adjust QOS
  adjustQOS

QST=$(cat << EOF
Would you like to continue with standard settings ?
Choose 'No' if you would like to use GPUs, local 
Scratch folders on Nodes or special queues/partitions.
EOF
)

  htyDialogYesNo "${QST}" "Continue with Standard Setup?"

  if [[ "${RES}" == "No" ]]; then 
     T="${RPART}"
     slurmSelectPartition "${MYPARTS}"
     if [[ "${T}" != "${RPART}" ]]; then
       #htyEcho "RPART: ${RPART}" 0
       adjustQOS
     fi
     slurmCheckPartition "${RPART}" "${MYACCTS}"
     slurmGetNodeInfo "${RPART}"
     slurmSelectGresFeatures
     adjustResources
  fi
  SEMAIL='name@org.edu'
  if htyInPath git; then
    SEMAIL=$(git config --global user.email)
  fi
  SBATCH+="#SBATCH --job-name=MyJob\n"
  if [[ -n ${DEFACCT} ]]; then 
    SBATCH+="#SBATCH --account=${DEFACCT}\n"
  fi
  SBATCH+="#SBATCH --partition=${RPART}\n"
  SBATCH+="#SBATCH --nodes=1 --ntasks=1\n"
  SBATCH+="#SBATCH --cpus-per-task=${RCORES}\n"
  SBATCH+="#SBATCH --mem-per-cpu=${RMEM}\n"
  SBATCH+="#SBATCH --time=${RTIME}\n"
  SBATCH+="#SBATCH --output=MyJob_%A_%a.out\n"
  SBATCH+="#SBATCH --error=MyJob_%A_%a.err\n"
  SBATCH+="#SBATCH --array=1-1%1                 # %13 = run 13 jobs in parallel\n"
  SBATCH+="#SBATCH --mail-type=FAIL,END          # or NONE/ALL or BEGIN,FAIL,END\n"
  SBATCH+="#SBATCH --mail-user=${SEMAIL}\n"
  [ -n "${RQOS}" ] && SBATCH+="#SBATCH --qos=${RQOS}\n"
  [ -n "${RGPU}" ] && SBATCH+="#SBATCH --gres=${RGPU}\n"
  [ -n "${RDISK}" ] && SBATCH+="#SBATCH --gres=${RDISK}\n"
  [ -n "${RFEAT}" ] && SBATCH+="#SBATCH --constraint=${RFEAT}\n"
  SBATCH=${SBATCH::-2} # strip final new line 
}


longterm(){
  SN=$(tmux list-sessions -F "#S" 2>/dev/null)
  if [[ -z ${SN} ]]; then
QST=$(cat << EOF
Starting a new TMUX session. This will allow you
to have one or more very long running terminal
sessions. You will be able to re-attach to these
sessions even after you disconnected for a long
weekend. If you type 'CTRL+B' and then 'D' you
can detach from the terminal instead of exiting.
Run: tmux new-session -s ${ME}1
EOF
)

    dialog --title "CTRL+B D to detach" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0

    clear
    htyEcho "Run: tmux new-session -s \"${ME}1\"" ${TWW}
    tmux new-session -s "${ME}1"
    return 0
  fi
  SN+=" -new-session- -exit-"
QST=$(cat << EOF
Please select the terminal session you would
like to re-connect to. You can also create a 
new session. 
You will be able to re-attach to these sessions
even after you disconnected for a long weekend. 
If you type 'CTRL+B' and then 'D' you can detach 
from the terminal instead of exiting.
EOF
)
  if ! htyDialogMenu "${QST}" "${SN}"; then 
    return 1
  fi
  if [[ "${RES}" == "-new-session-" ]]; then
QST=$(cat << EOF
Please confirm the session name or enter a new
session name, for example a project name you 
will be working on for a while. 
If you type 'CTRL+B' and then 'D' you can detach
from the terminal instead of exiting.
EOF
)
    SID=$(wc -w <<<${SN})
    ! htyDialogInputbox "${QST}" "${ME}${SID}" && return 1
    S=${RES// /_}   
    htyEcho "Run: tmux new-session -s \"${S}\"" ${TWW}
    tmux new-session -s "$S"
  elif [[ "${RES}" == "-exit-" ]]; then
    return 0 
  elif [[ -n ${RES} ]]; then
    htyEcho "Run: tmux attach -t \"${RES}\"" ${TWW}
    tmux attach -t "${RES}"
  fi
}

## Create a Slurm job array 

arrayjob() {
  #MSG="${FUNCNAME[0]} <binary> <script>"
  #[[ -z $1 ]] && echo ${MSG} && return 1
  MYBIN=$1;  MYSHEBANG=""; RES=""
  [[ $1 == "R" ]] && MYBIN="Rscript"
  [[ $1 == "python" ]] && MYBIN="python3"
QST=$(cat << EOF
We will now create a Slurm job array and submit
it to the cluster. The idea of job arrays is
that you have one script that is executed many 
times and each time with a different data file.
Each combination of script and data file is an
array job and the collection of all data files 
and the script is called a job array.
As part of this process we will use common best 
practices, manage our code with Git, and ensure 
that code and data are kept in separate folders.
Please enter a short but meaningful name or id 
for your job array. You will use it to track 
progress with your compute jobs.
EOF
) 
  MYJOBARR=$(htyReadConfigOrDefault "lastjobarray" "${ME}-jobs-0")
  MYJOBARR=$(htyIncrementTrailingNumber "${MYJOBARR}")	   
  htyDialogInputbox "${QST}" \
      "${MYJOBARR}" "Job Array Name" \
      || return 1
  MYJOBARR=${RES// /-}
  echo "${MYJOBARR}" > ~/.config/hpctoys/lastjobarray
  
QST=$(cat << EOF
Now we select a project folder name that has a 
Python, R, or Shell (other) script but NO data.
If you do not have a project folder with a script 
yet, please enter a new folder name without path 
below and in the next step you use the folder 
browser to select the path where this new folder
will be created. 

If your project folder is not inside a Git repos
yet, this process will initialize a new Git repos
for you. Note, that all dots, underscores and 
spaces in your folder name will be replaced with h
yphens to ensure this folder name can be in a URL 
on Github later.

Enter a project folder name or leave blank to
select an existing folder with the folder browser
in the next step.
EOF
)
  RES=""
  htyDialogInputbox "${QST}" "" \
      "${MYJOBARR} Folder" || return 1
  REPOSFLD=""
  NEWFLD=""

  if [[ -n ${RES} ]]; then
    NEWFLD=${RES}
    QST=$(cat << EOF
Please select a folder in which we create your
new project sub folder "${NEWFLD}".
You can either select a previously used folder
or you start from 'root' or 'home' and browse 
through the folders with the arrow keys and 
confirm your selection with 'Enter'.
EOF
)     
  else
QST=$(cat << EOF
Please select the existing folder that contains 
your code files. This folder cannot exceed 10MB
in size. 
EOF
)
  fi

  htyFolderSel "${QST}" || return 1
  REPOSFLD=${RES}

  if [[ -z ${NEWFLD} ]]; then
    MAXSIZEFLD=10240 # 10MB max size
    SIZEFLD=(du -s "${REPOSFLD}")
    if [[ ${SIZEFLD} -gt ${MAXSIZEFLD} ]]; then
      QST=$(cat << EOF
The folder you chose is larger than 10 MB which
is not supported by HPC Toys. Remember that code
and data must be stored in different locations.
Please enter a new project folder name that 
will be created inside ${REPOSFLD}. 
EOF
)     
      htyDialogInputbox "${QST}" "${ME}-project-1" \
      "${MYJOBARR} Folder" || return 1 
      NEWFLD=${RES}
    fi
  fi

  if [[ -n ${NEWFLD} ]]; then
    NEWFLD=${NEWFLD// /-}
    NEWFLD=${NEWFLD//_/-}
    NEWFLD=${NEWFLD//./-}
    NEWFLD=$(htyRemoveTrailingSlashes "${NEWFLD}")
    eval REPOSFLD=${REPOSFLD}/${NEWFLD}
    mkdir -p "${REPOSFLD}"
    htyEcho "${REPOSFLD}"
  fi

  # REPOSFLD is now set, expand and initialize git repos
  eval REPOSFLD="${REPOSFLD}"
  PLAINFLD=$(basename "${REPOSFLD}")
  # this needs to change to allow more options
  GHORG=$(htyReadConfigOrDefault "github_login") 

  if ! htyGitIsInRepos "${REPOSFLD}"; then
    if htyGitInitRepos "${REPOSFLD}"; then
       ##########
      QST=$(cat << EOF
Git repository "${PLAINFLD}" was created with:
  git init
  git symbolic-ref HEAD refs/heads/main
  git add -A .
  git commit -a -m "Initial commit" 

Would you also like to create this repostory on
Github? 

If you select 'Yes', I will run these commmands:
  git remote add origin git@github.com:${GHORG}/${PLAINFLD}.git
  git remote -v
  git push --set-upstream origin main

Before you hit 'Yes', please ensure that this 
empty private repository exists: 
github.com:${GHORG}/${PLAINFLD} 
EOF
)
      if dialog --yesno "${QST}" 0 0; then
	OUT=$(mktemp "${TMPDIR}/hpctoys.XXXXX")
	TIT="Error initializing Github repos"
	if git ls-remote git@github.com:${GHORG}/${PLAINFLD} \
  	                           >> "${OUT}" 2>&1; then
          if htyGithubInitRepos "${GHORG}/${PLAINFLD}" \
		     "${REPOSFLD}" >> "${OUT}" 2>&1 ; then
            TIT="Successfully initialized Github repos"
	  fi
	else 
	  TIT="Error accessing Github repository"
	  echo "" >> "${OUT}"
	  echo "Unable to list github.com:${GHORG}/${PLAINFLD}" >> "${OUT}" 
	  echo "Have you created an empty private repository with " >> "${OUT}"
	  echo "NO .gitignore, README.md or license on github.com ?" >> "${OUT}"
	fi
	dialog --backtitle "HPC Toys" \
	       --title "${TIT}"  \
	       --tailbox "${OUT}" 0 0
      fi
    fi
  fi

  ####### let's pick the Code file """""""

  MYFILE="- Create New File -"

  # are there even existing files in there ?
  N=$(htyFilesPlain "${REPOSFLD}" | wc -w)
  if [[ $N -gt ${GITMINFILES} ]]; then
    QST=$(cat << EOF
Now select the code file you would like to use
for your array job. This should be a file ending
with .py or .R or .sh. If you are not seeing 
a suitable file please use "- Create New File -"
EOF
)
    htyFileSel "${QST}" "${REPOSFLD}"  "*" "0" \
             "- Create New File -" || return 1
    MYFILE="${RES}"
  fi

  if [[ "${MYFILE}" =~ "- Create New File -" ]]; then
      QST=$(cat << EOF
"${REPOSFLD}" is empty.
Please enter a file name that ends with .py or  
.R! If you do not enter a file extension, a Slurm
submission script with an extension .sub will be 
created.
EOF
)    
    htyDialogInputbox "${QST}" "" \
	"Create New File" || return 1
      MYFILE="${RES}"
      MYFILE=$(htyRemoveTrailingSlashes "${MYFILE}")
      MYFILE=${MYFILE// /-}
  fi

  if [[ -e "${REPOSFLD}/${MYFILE}" ]]; then
    X=$(head -c 4 "${REPOSFLD}/${MYFILE}" | tail -c 3)
    if [[ ${X^^} == "ELF" ]]; then 
      echo "${MYFILE} is a binary file, only script files supported"
    fi
  fi

    
  #### Select data files, one and more folders 

  DQST=$(cat << EOF
Now we need to select the folders that contain 
the data files you would like to use. 
You can select data files from multiple folders. 
After you have selected your folder you can 
check multiple files for processing.
EOF
)

  FQST=$(cat << EOF
Now we need to select the data files you would
like to run with your script. You can check files
or simply choose "- all files -" to include all
files in that folder.
Selected filenames will be saved to a list called
filelists/${MYJOBARR}.filelist.txt 
EOF
)

  FLDEND=""  # yes = select no more folders
  MYDATA=()  # Array that contains all selected files
  while [[ -z "${FLDEND}" ]]; do 
    htyFolderSel "${DQST}" "" "Select Data Folder" \
               || FLDEND='yes'
    eval FLD="${RES}"
    if [[ "${FLD}" == "${REPOSFLD}" ]]; then 

QST=$(cat << EOF
Data and Code folders need to be separate
EOF
)
      dialog --title "Separate folders !" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0

      continue 
    fi 
    NOFILES=""
    INSRT=${#MYDATA[@]}
    N=$(htyFilesPlain "${FLD}" | wc -w)
    if [[ $N -eq 0 ]]; then
      NOFILES="No files found in Folder ${FLD}.\n"
    fi
    if [[ -z "${FLDEND}" ]] && [[ $N -gt 0 ]]; then
      IFS=$'\n'
      htyFileSelMulti "${FQST}" "${FLD}" "*" "0" \
	"- all files -" || FLDEND='yes'
      unset IFS
      #htyEcho "${RES}" 0
      if [[ -z "${FLDEND}" ]]; then
	if [[ "${RES}" =~ "- all files -" ]]; then
	  readarray -O ${INSRT} -t \
	         MYDATA < <(htyFilesFull "${FLD}")
	else
          eval RESARR=(${RES})
	  for F in "${RESARR[@]}"; do 
	    MYDATA+=("${FLD}/${F}")
	  done
	fi
      fi 
    fi
    QST=$(cat << EOF
End file selection?
Choose 'No' to select more files 
from other data folders!
EOF
)
    dialog  --title "Done selecting files ?" \
            --backtitle "HPC Toys" \
            --yesno "${NOFILES}${QST}" 0 0 \
                   && FLDEND='yes'
  done
  # write MYDATA array to file
  mkdir -p "${REPOSFLD}/filelists"
  FILELISTTXT="${REPOSFLD}/filelists/${MYJOBARR}.filelist.txt"
  printf "%s\n" "${MYDATA[@]}" > "${FILELISTTXT}"

  # in addition create symlinks for each array
  mkdir -p "${REPOSFLD}/filelists/${MYJOBARR}.filelist"
  for F in "${MYDATA[@]}"; do 
    B=$(basename "${F}")
    ln -sfr "${F}" "${REPOSFLD}/filelists/${MYJOBARR}.filelist/${B}"
  done
  
# Now building a job and adding a few special Array job options

#  SBATCH+="#SBATCH --job-name=MyJob\n"
#  SBATCH+="#SBATCH --account=${DEFACCT}\n"
#  SBATCH+="#SBATCH --partition=${RPART}\n"
#  SBATCH+="#SBATCH --ntasks=1 --nodes=1\n"
#  SBATCH+="#SBATCH --cpus-per-task=${RCORES}\n"
#  SBATCH+="#SBATCH --mem-per-cpu=${RMEM}\n"
#  SBATCH+="#SBATCH --time=${RTIME}\n"
#  SBATCH+="#SBATCH --output=MyJob_%A_%a.out\n"
#  SBATCH+="#SBATCH --error=MyJob_%A_%a.err\n"
#  SBATCH+="#SBATCH --array=1-1%1\n"  # %X=run 
#  SBATCH+="#SBATCH --mail-type=FAIL,END  #or NONE/ALL or BEGIN,FAIL,END\n"
#  SBATCH+="#SBATCH --mail-user=${SEMAIL}\n"
#  [ -n "${RQOS}" ] && SBATCH+="#SBATCH --qos=${RQOS}\n"
#  [ -n "${RGPU}" ] && SBATCH+="#SBATCH --gres=${RGPU}\n"
#  [ -n "${RDISK}" ] && SBATCH+="#SBATCH --gres=${RDISK}\n"
#  [ -n "${RFEAT}" ] && SBATCH+="#SBATCH --constraint=${RFEAT}\n"
  
  # create the sbatch directives 
  buildjob  

  SBATCH=${SBATCH//MyJob/${MYJOBARR}}
  #if we have move than 25 data files ask how many jobs 
  #should be run in parallel. 
  ARRSIZE=${#MYDATA[@]}
  PARJOBS="${ARRSIZE}" 

  if [[ "${ARRSIZE}" -gt 25 ]]; then 
QST=$(cat << EOF
You have selected ${ARRSIZE} data files. How many
array jobs would you like to run in parallel? 
If you share your HPC account with your team 
members you can reduce the number of jobs that
you run in parallel to leave more compute 
capacitly for others.
EOF
)
    htyDialogInputbox "${QST}" \
        "${ARRSIZE}" "How many Jobs in parallel? " \
        || return 1
    PARJOBS="${RES}"   
  fi

  # replace standard array with a larger one
  SBATCH=${SBATCH/--array=1-1%1/--array=1-${ARRSIZE}%${PARJOBS}} 

  ## checking if R or Python or Shell or other

  MYEXT=${MYFILE##*.}
  if [[ "${MYEXT}" == "${MYFILE}" ]]; then
    MYEXT="sub"
    MYBIN="bash"
  fi
  if [[ "${MYEXT,,}" == "r" ]]; then
    # converting to lowercase
    MYEXT='R'
    MYBIN="Rscript"
  elif [[ "${MYEXT,,}" == "py" ]]; then
    MYEXT='py'
    MYBIN='python3'
  elif [[ "${MYEXT,,}" == "sh" ]]; then
    MYEXT='sh'
    MYBIN='sh'
  fi

 CODEPATH="${REPOSFLD}/${MYFILE}"
 if ! [[ -e "${CODEPATH}" ]]; then
   touch "${CODEPATH}"
 fi


  ### Now we are ready to create or modify our submission
  ### script which has 5 components:
    # 1. Shebang line (1st line)
    # 2. #SBATCH directives
    # 3. import (Python) or library statements (R)
    # 4. HPC Toys boilerplate code
    # 5. Actual code
    #
    # Most scripts will have 3. and 5. and many
    # will have 1. so this tool will optionally
    # insert 1., 2. and 4. if it does not exist.
    # It will replace 2. each time 
    #
  ### If code file MYFILE is a linux ELF binary
    # we will create a new submission script ${MYJOBARR}.sh
    # and ask the user  if create it in a different location

  #check if the script starts with the right shebang
  SHEBANG=$(head -n 1 "${CODEPATH}" | \
            grep '^#!.*'"${MYBIN}"'$')
  #if ! head -n 1 "${CODEPATH}" | \
  #          grep -q '^#!.*'"${MYBIN}"'$'; then
  if [[ -z "${SHEBANG}" ]]; then      
    SHEBANG="#! /usr/bin/env ${MYBIN}"
  fi

  # get R, Python & shell snips
  codesnips
  
  # copy actual code to tmp file removing Shebang & SBATCH  
  grep -v '^#!\|^#SBATCH ' "${CODEPATH}" > \
                           "${CODEPATH}.tmp"
  if grep -q '^##### Begin HPC Toys' "${CODEPATH}"; then
    # file has previously been edited by HPC Toys, rewrite 
    echo -e "${SHEBANG}\n${SBATCH}" > "${CODEPATH}"
    cat "${CODEPATH}.tmp" >> "${CODEPATH}"
  else
    if [[ ${MYEXT} == "R" ]]; then
      IMPORTS=$(grep '^library(' "${CODEPATH}")
      grep -v '^library(' "${CODEPATH}.tmp" \
                 > "${CODEPATH}.tmp.R"
      echo -e "${SHEBANG}\n${SBATCH}" > "${CODEPATH}"
      [[ -n "${IMPORTS}" ]] && echo -e "${IMPORTS}" >> "${CODEPATH}"
      echo "${SNIP_R}" >> "${CODEPATH}"
      cat "${CODEPATH}.tmp.R" >> "${CODEPATH}"
      rm -f "${CODEPATH}.tmp.R"
    elif  [[ ${MYEXT} == "py" ]]; then
      IMPORTS=$(grep '^import \|^from .* import' "${CODEPATH}")
      grep -v '^import \|^from .* import' "${CODEPATH}.tmp" \
                 > "${CODEPATH}.tmp.py"
      echo -e "${SHEBANG}\n${SBATCH}" > "${CODEPATH}"
      [[ -n "${IMPORTS}" ]] && echo -e "${IMPORTS}" >> "${CODEPATH}"
      echo "${SNIP_PY}" >> "${CODEPATH}"
      cat "${CODEPATH}.tmp.py" >> "${CODEPATH}"
      rm -f "${CODEPATH}.tmp.py"
    fi
  fi
  # now write a shell submit script in addition to the above
  
  rm -f "${CODEPATH}.tmp"
  chmod +x "${CODEPATH}"

  # now write a shell submit script in addition to the above
  MYSUB="${REPOSFLD}/${MYJOBARR}.sub"
  if [[ -e "${MYSUB}" ]]; then 
    grep '^module load \|^ml ' "${MYSUB}" > "${MYSUB}.tmp"
  fi
  echo -e "#! /bin/bash\n${SBATCH}" > "${MYSUB}"
  echo "${SNIP_BASH//#MOREARGS/myargs+=(\"${FILELISTTXT}\")}" >> "${MYSUB}"
  echo -e "\n#module load something some/ohterthing\n" >> "${MYSUB}"
  if [[ -e "${MYSUB}.tmp" ]]; then
    cat "${MYSUB}.tmp" >> "${MYSUB}"
    rm -f "${MYSUB}.tmp"
  fi
  
  echo "# You can add more arguments to the script, " >> "${MYSUB}" 
  echo "# for example \"\${datafiles[2]}\" or \"\${datafiles[3]}\"" >> "${MYSUB}"
  echo "\"${CODEPATH}\" \"\${datafiles[1]}\"" >> "${MYSUB}"
  echo "find . -maxdepth 1 -name '*.err' -size 0 -delete 2>/dev/null" >> "${MYSUB}"

  #cat "${CODEPATH}"
  #Now we want to execute the script  

  QST=$(cat << EOF
Would you like to start the batch job 
using this command now ? :  
sbatch "${MYSUB}"
EOF
)
  if dialog  --title "Start Batch Job ?" \
             --backtitle "HPC Toys" \
             --yesno "${QST}" 0 0; then

    mkdir -p jobs 
    cd jobs
    J=$(sbatch --parsable "${MYSUB}" 2>&1)
    E=$?
    cd ..
    if [[ $E -gt 0 ]]; then 

QST=$(cat << EOF
The Job submission failed with error code ${E}.
Error Message from Slurm:
${J}
EOF
)
      dialog --title "Error submitting job!" \
             --backtitle "HPC Toys" \
             --msgbox "${QST}" 0 0

    else
      JID=${J%%;*} # could be multiple clusters
      JID=${JID%%_*} # cloud be job array ?
      
      # another way to get status of running job:
      # squeue -j 20827861 --noheader --format %t      
      SEL=""
      TMT=5
      FLS=""
      while [[ -z "${FLS}" ]]; do
        SQ=$(squeue -j "${JID}" --noheader --format "%S;%R")
        STTIME=${SQ%%;*}
        REASON=${SQ##*};
        [[ "${REASON}" == "(None)" ]] && REASON="" 
        QST=$(cat << EOF
Waiting ${TMT} sec for start of job ${JID}.
Expected start time: ${STTIME}
Hit 'Space' or 'Enter' to skip the wait and
re-check the ./jobs folder for output files.

Wait increases by 10 sec each loop; select
cancel to stop waiting. Slurm wait reason:

${REASON}
EOF
) 
        dialog --title "Waiting for output" \
               --backtitle "HPC Toys" \
               --pause "${QST}" 20 50 ${TMT}
        [[ $? -ne 0 ]] && break        
        FLS=$(htyFilesPlain ./jobs '*'"${JID}"'*')
        ((TMT+=10))        
      done 

      QST=$(cat << EOF
Check output files for job id ${JID}.
Will run 'less +F <file>' to check progress of 
output of that job. For other file operations 
select '- More options -'.
(Hit 'q' to leave the less tool after exiting
follow mode with CTRL+C)
EOF
)
      if [[ -n "${FLS}" ]]; then 
        SEL="" 
	while [[ -z "${SEL}" ]]; do
	  if htyFileSel "${QST}" ./jobs '*'"${JID}"'*' "0" "- More options -"; then
	    SEL="${RES}"
	    RES=""
	    if [[ "${SEL}" == "- More options -"  ]]; then 
	      dialog --title "More Options!" \
		     --backtitle "HPC Toys" \
		     --msgbox "This feature is not yet implemented" 0 0
	     
	    else
	      less -N "./jobs/${SEL}"  #+F / --quit-on-intr quits everything
	    fi
	    SEL=""
	  else        
	    break
	  fi
	done
      fi
    fi
    #htyEcho "${RES}" 0
  else

    htyEcho "\nTo test the first array job you can simply run:"
    htyEcho "\"${CODEPATH}\" \"${REPOSFLD}/filelists/${MYJOBARR}.filelist.txt\""

    htyEcho "\nTo execute the entire job array execute this command:"
    htyEcho "sbatch \"${CODEPATH}\" \"${REPOSFLD}/filelists/${MYJOBARR}.filelist.txt\""

    htyEcho "\nOr you run the submit script to execute the entire job array"
    htyEcho "sbatch \"${MYSUB}\"" 0

  fi
                  
}

codesnips() {

 SNIP_PY=$(cat << EOF
#
##### Begin HPC Toys ##########
# read from one or multiple files that are passed 
# as command line arguments. If the filename ends
# *.filelist.txt, read from a data file listed in 
# the Nth line of  *.filelist.txt where 
# N = SLURM_ARRAY_TASK_ID = tid
# 
# a function to retrieve the data files 
def getDataFiles():
    import sys,os
    datafiles=[]
    if len(sys.argv)-1 == 0:
        return datafiles
    tid = os.environ.get("SLURM_ARRAY_TASK_ID","1")
    # we store task id as first element of datafiles list
    datafiles.append(tid)
    for i in range(1, len(sys.argv)):
        argfile = sys.argv[i]
        if not os.path.exists(argfile): continue 
        if not argfile.endswith('.filelist.txt'):
            datafiles.append(argfile)
            continue
        with open(argfile, "r") as fh:
            filelist = fh.readlines()
        if len(filelist) < int(tid):
            print("TASK_ID %s larger than number of data files" % tid )
            continue
        datafile=filelist[int(tid)-1].strip()
        if not os.path.exists(datafile):
            print("Data file %s does not exist." % datafile)
            continue
        datafiles.append(datafile)
    return datafiles

# using the datafiles list in your code
datafiles = getDataFiles()
if len(datafiles) > 1:
    # start reading with index=1
    for i in range(1,len(datafiles)):
        print (" *** Python TASK_ID %s: 1st 3 lines of %s" % (datafiles[0],datafiles[i]))
        j=0
        with open(datafiles[i], "r") as fh:
            for line in fh:
                print (line.strip())
                j+=1
                if j == 3:
                    break
##### End HPC Toys ##########
EOF
)


# Bioc uses 4 spaces: 
# https://contributions.bioconductor.org/r-code.html#indentation
 SNIP_R=$(cat << EOF
#
##### Begin HPC Toys ##########
# read from one or multiple files that are passed
# as command line arguments. If the filename ends
# *.filelist.txt, read from a data file listed in
# the Nth line of  *.filelist.txt where
# N = SLURM_ARRAY_TASK_ID = tid
#
getDataFiles <- function() {
    args <- commandArgs(TRUE)
    datafiles <- character()  #initialize a str vector
    if (length(args) == 0) {
        return(datafiles)
    }
    tid <- Sys.getenv(c("SLURM_ARRAY_TASK_ID"))
    if (tid == '') {tid <- "1"}
    # we do NOT store task id as first element 
    # because R lists are not zero based 
    for (i in 1:length(args)){
        argfile = args[i]
        if (!file.exists(argfile)) {
            next
        }
        if (!endsWith(argfile, ".filelist.txt")){
            datafiles <- append(datafiles, argfile)
            next
        }
        fh <- file(argfile, "r")
        filelist <- readLines(fh)
        close(fh)
        if (length(filelist) < strtoi(tid)) {
          cat("Task ID larger than number of data files")
          next
        }
        datafile=filelist[strtoi(tid)]
        if (!file.exists(datafile)) {
            cat("Data file does not exist.")
            next
        }
        datafiles <- append(datafiles,datafile)
    }
    return(datafiles)
}

# using the datafiles list in your code
datafiles <- getDataFiles()
if (length(datafiles) > 0) {
    # start reading with index=1
    #tid <- Sys.getenv(c("SLURM_ARRAY_TASK_ID"))
    for (i in 1:length(datafiles)){
        cat (" *** R TASK: 1st 3 lines of ", datafiles[i],'\n')
        writeLines(readLines(datafiles[i], n=3))
    }
}
##### End HPC Toys ##########
EOF
)

 SNIP_BASH=$(cat << EOF
#
##### Begin HPC Toys ##########
# read from one or multiple files that are passed
# as command line arguments. if the filename ends
# *.filelist.txt, read from a data file listed in
# the Nth line of  *.filelist.txt where
# N = SLURM_ARRAY_TASK_ID = tid
#
# a function to retrieve the data files
getDataFiles() {
  [[ -z "\${myargs[@]}" ]] && return 0
  tid="\${SLURM_ARRAY_TASK_ID}"
  [[ -z \${tid} ]] && tid="1"
  # we store task id as first element of datafiles list
  datafiles+=("\${tid}")
  for argfile in "\${myargs[@]}"; do
    [[ -e "\${argfile}" ]] || continue
    if ! [[ "\${argfile}" == *".filelist.txt" ]]; then
      datafiles+=("\${argfile}")
      continue
    fi
    readarray -t filelist < "\${argfile}"
    if [[ \${#filelist[@]} -lt \${tid} ]]; then
      echo "TASK_ID \${tid} > no of data files";
      continue
    fi
    ((id=tid-1)); datafile=\${filelist[\${id}]}
    if ! [[ -e "\${datafile}" ]]; then
      echo "File "\${datafile}" does not exist"
      continue
    fi
    datafiles+=("\${datafile}")
  done
  return 0
}

# using the datafiles array in your code
declare -a datafiles myargs
myargs=( "\$@" )
#MOREARGS
getDataFiles
let numf=\${#datafiles[@]}-1
if [[ \${numf} -ge 1 ]]; then
  # start reading with index=1
  echo "*** Printing file from *.sub script:"
  for i in \$(seq 1 \${numf}); do
    echo "\$i: 1st 3 lines of data file: \${datafiles[\$i]}"
    head -n 3 "\${datafiles[\$i]}"
  done
  echo "*** Printing file from other script:"
fi
##### End HPC Toys ##########
EOF
)

}

myjobs(){
  squeue  -u "${ME}" --format '"%i","%j","%t","%M","%L","%D","%C","%m","%b","%R"' > "${TMPDIR}/${ME}-squeue.csv" # -u "${ME}"
  if [[ $(wc -l < "${TMPDIR}/${ME}-squeue.csv") -le 1 ]]; then
    dialog --title "No Jobs!" \
           --backtitle "HPC Toys" \
           --msgbox "You have no Slurm jobs running. Please start a job and try again" 0 0
    return 0     
  fi 
  H='"JOBID","NAME","ST","TIME","TM-LEFT","ND","CPUS","MEM","TRES","NODELIST(REASON)"'
  sed -i "1s/.*/${H}/" "${TMPDIR}/${ME}-squeue.csv"
  LST=$(awk -F',' '{gsub(/"/, "");(NR>1); print $1"+"$2}' "${TMPDIR}/${ME}-squeue.csv")
  htyEcho "Loading jobs ... (Enter q to exit view)"
  rich --pager \
       --title "Cluster jobs for ${ME} (Enter q to quit)" \
       --caption "Enter q to quit" \
       --csv "${TMPDIR}/${ME}-squeue.csv"

QST=$(cat << EOF
If you would like to see more details on 
your jobs please select one of the job 
IDs below.
EOF
)
  LST=${LST##*JOBID+NAME}
  [[ -z "${LST}" ]] && return 0
  LST1="-Cancel-Jobs-${LST}"

  #htyEcho "${LST1}" 0

  htyDialogMenu "${QST}" "${LST1}" "" "Select Job ID"
  JID=${RES%%+*}
  JID=${JID%%_*} # cloud be job array ?
  [[ -z "${JID}" ]] && return 0
  if [[ "${JID}" == "-Cancel-Jobs-" ]]; then 
QST=$(cat << EOF
Please select all jobs you 
would like to cancel !
EOF
)
    htyDialogChecklist "${QST}" "${LST}" "" "Select Job IDs to Cancel"
    for JID in ${RES}; do 
       scancel ${JID%%+*}
    done     
  else
    s-jobinfo "${JID}"
    htyEcho "\n s-jobinfo ${JID}" 0 
  fi

}

spinner() {
  htySpinner "$!"
}


quiet() {
  echo "1" > ~/.config/hpctoys/quiet
  htyEcho "Disabled message at login time."
}

help(){
  echo " ${SCR} longterm"
  echo " ${SCR} arrayjob"
  echo " ${SCR} sshkey (refresh key from .ssh/id_rsa.pub)"
  echo -e "\nfor example:"
  echo -e " ${SCR} create -f ${OPT_f} -i \"${OPT_i}\" myserver"
}

args() {
  while getopts a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z: OPTION "$@"; do
    echo "OPTION: -${OPTION} ARG: ${OPTARG}"
    eval OPT_${OPTION}=\$OPTARG
  done
  shift $((OPTIND - 1))
  printf " arg: '%s'" "$@"
  echo ""
}

SUBCOMMANDS='longterm|arrayjob|interactive|myjobs|spinner|quiet|help|args'
if [[ ${SUBCMD} =~ ^(${SUBCOMMANDS})$ ]]; then
  ${SUBCMD} "$@"  
else
  echo "Invalid subcommand: ${SUBCMD}" >&2
  help
  exit 1
fi

