# Global settings for all users in your group.
# After   
# git clone https://github.com/dirkpetersen/hpctoys.git
# cd hpctoys
# install.sh

GID_SUPERUSERS=111111
UID_APPMGR=222222
export LPYTHONVER="3.11.0"

# helper functions 
echoerr() {
  # echo to stderr instead of stdout
  echo -e "$@" 1>&2
}
htyInGroup() { [[ " $(id -G $2) " == *" $1 "* ]]; }   #is user in group (gidNumber)
htyInPath() { builtin type -P "$1" &> /dev/null ; }   #is executable in path
htyMkdir(){
  # htyMkdir "<dir-name>"
  if ! [[ -d "$1" ]]; then
    mkdir -p  "$1"
  fi
}
htyAddLineToFile() {  
  # htyAddLineToFile <line> <filename>
  MSG="${FUNCNAME[0]} <line-to-be-added> <file-that-exists>"
  [[ ! -f $2 ]] && echo ${MSG} && return 1
  if ! grep -q "^$1" "$2"; then
    echo "$1" >> "$2"
  fi
}
htyAddLineBelowLineToFile() {
  # htyAddLineBelowLineToFile <add-this> <below-this> <filename>
  if ! grep -q "^$1" "$3"; then
    sed -i "|^$2*|a $1" "$3"
  fi
}
htyReplaceLineInFile() {
  MSG="${FUNCNAME[0]} <line-to-be-replaced> <replacement-line> <file-that-exists>"
  [[ ! -f $3 ]] && echo ${MSG} && return 1
  if ! grep -q "^$2" "$3"; then
    sed -i "s|^$1*|$2|g" "$3"
  fi
}
htyReplaceCommentLineInFile() {
  MSG="${FUNCNAME[0]} <line-to-be-commented> <replacement-line> <file-that-exists>"
  [[ ! -f $3 ]] && echo ${MSG} && return 1
  if ! grep -q "^$2" "$3"; then
    sed -i "s|^$1|#$1\n$2|g" "$3"
  fi
}

htyFilesPlain() {
  MSG="${FUNCNAME[0]} <folder> <file-or-wildcard>"
  [[ -z $1 ]] && echo ${MSG} && return 1
  if [[ -z $2 ]]; then
    ls -1 $1
  else
    CD=$(pwd)
    cd $1
    ls -1 $2
    cd ${CD}
  fi
}

htyIsItemInList() {
  MSG="${FUNCNAME[0]} <item> <list of items>"
  [[ -z $2 ]] && echo ${MSG} && return 1
  for X in $2; do
    [[ "$1" == "$X" ]] && return 0
  done
  return 1
}

htyDialogInputbox() {
  # wrapper for unix dialog --inputbox
  #read -n 1 -r -s -p $"\n $1 $2 $3 Press enter to continue...\n"
  MSG="${FUNCNAME[0]} <message> <default-value>"
  [[ -z $2 ]] && echo ${MSG} && return 1
  RES="" 
  while [[ "$RES" == "" ]]; do 
    RES=$(dialog --inputbox "$1" 0 0 "$2" 2>&1 1>/dev/tty)
    RET=$?
    #echo $RET:$RES && sleep 3
    if [[ $RET -ne 0 ]]; then
      clear
      echoerr "\n Setup canceled, exiting ...\n"
      exit
    fi
  done
  clear
}

htyDialogChecklist() {
  # wrapper for unix dialog --checklist
  #read -n 1 -r -s -p $"\n  $1 $2 $3 Press enter to continue...\n"
  MSG="${FUNCNAME[0]} <message> <list-of-options> <selected-options>"
  [[ -z $2 ]] && echo ${MSG} && return 1
  OPT=""
  RES=""
  i=0
  for E in $2; do 
    let i++
    if [[ " $3 " =~ .*\ ${E}\ .* ]]; then
      OPT+="$E $i on "
    else 
      OPT+="$E $i off "
    fi  
  done
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --checklist "$1" 0 0 0 ${OPT} 2>&1 1>/dev/tty) 
    RET=$?
    #echo $RET:$RES && sleep 3
    if [[ $RET -ne 0 ]]; then
      clear
      echoerr "\n Setup canceled, exiting ...\n"
      exit
    fi
  done
  clear
}

htyReadConfigOrDefault() {
  # htyReadConfigOrDefault <setting> <default>
  if [[ -f ~/.config/hpctoys/$1 ]]; then 
    echo "$(cat ~/.config/hpctoys/$1)"
  elif [[ -f ${HPCTOYS_ROOT}/etc/hpctoys/$1 ]]; then
    echo "$(cat ${HPCTOYS_ROOT}/etc/hpctoys/$1)"
  else 
    echo "$2"
  fi
}
htyAppendPath() {
  # remove from PATH and add to end of PATH 
  for ARG in "$@"; do
    PATH=${PATH//":${ARG}"/} #delete any instances in the middle or at the end
    PATH=${PATH//"${ARG}:"/} #delete any instances at the beginning
    if [[ -d "$ARG" ]]; then  #&& [[ ":$PATH:" != *":$ARG:"* ]]; then
      PATH="${PATH:+"$PATH:"}$ARG"
    fi
  done
}
htyPrependPath() {
  # remove from PATH and add to beginning of PATH
  for ((i=$#; i>0; i--)); do
    ARG=${!i}
    PATH=${PATH//":${ARG}"/} #delete any instances in the middle or at the end
    PATH=${PATH//"${ARG}:"/} #delete any instances at the beginning
    if [[ -d "$ARG" ]]; then  #&& [[ ":$PATH:" != *":$ARG:"* ]]; then
      PATH="$ARG${PATH:+":$PATH"}"
    fi
  done
}
htyIntVersion() { 
  # convert version to integer to allow comparison of versions 
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; 
}
htyLoadLmod() {
  # load last found module that starts with $1 
  # (capture both STDOUT and STDERR from 'ml avail') 
  if [[ -z $1 ]]; then
    echo "please enter start of your module names, e.g. gcc libffi"
    return 1
  fi
  . <({ LERR=$({ LOUT=$(ml --terse avail); } 2>&1; declare -p LOUT >&2); declare -p LERR; } 2>&1)
  AVAIL="${LOUT}"
  if [[ -z "${AVAIL}" ]]; then
    AVAIL="${LERR}"
  fi
  for M in "$@"; do
    ml $(grep -i "^${M}" <<< "${AVAIL}" | tail -1)
  done
}




initSpack(){
  # initSpack 
  if [[ -d "${SPACK_ROOT}" ]]; then
    . ${SPACK_ROOT}/share/spack/setup-env.sh
    if ! [[ -f  "${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash" ]]; then
       echoerr "Spack environment not setup, run hpctoys installer... "
    else
       . $(cat "${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash")
    fi
  fi
}
initEasybuild(){
  # Easybuild Settings
  EASYBUILD_JOB_CORES=4
  EASYBUILD_CUDA_COMPUTE_CAPABILITIES=7.5,8.0,8.6,9.0
  EASYBUILD_BUILDPATH=/dev/shm/${WHOAMI}
  EASYBUILD_PREFIX=$1
  EASYBUILD_JOB_OUTPUT_DIR=$1/slurm-output
  EASYBUILD_JOB_BACKEND=Slurm
  EASYBUILD_PARALLEL=16
  ### EASYBUILD_GITHUB_USER=${WHOAMI}
  EASYBUILD_UPDATE_MODULES_TOOL_CACHE=True
  #EASYBUILD_ROBOT_PATHS=/home/scicompappsvc/.local/easybuild/easyconfigs:/app/eb/fh/fh_easyconfigs/:/app/eb/mcc/mcc_easyconfigs/
}
initLpython() {
  export LPYTHON="/tmp/hpctoys/lpython/bin/python${LPYTHONVER::-2}"
  export PATH="$PATH:${HPCTOYS_ROOT}/opt/python/bin:/tmp/hpctoys/lpython/bin"
  LPYTHONLIB="/tmp/hpctoys/lpython/lib/libpython${LPYTHONVER::-2}.a"
  PYARCHIVE="${HPCTOYS_ROOT}/opt/lpython-${LPYTHONVER}.tar.xz"
  CURRMASK=$(umask)
  if ! [[ -f "${LPYTHON}" && -f "${LPYTHONLIB}" ]]; then
    echoerr " preparing local Python ${LPYTHONVER} installation ..."
    umask 0000
    mkdir -p "${TMPDIR}/hpctoys"
    if [[ -f "${PYARCHIVE}" ]]; then
      tar xf ${PYARCHIVE} -C "${TMPDIR}/hpctoys"
    else
      echoerr " File ${PYARCHIVE} does not exist, please run 'install.sh lpython'"
    fi
    umask ${CURRMASK}
  fi
  #if [[ -f "${HPCTOYS_ROOT}/opt/openssl/bin/openssl" ]]; then
  #  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${HPCTOYS_ROOT}/opt/openssl/lib
  #fi
  # sets pip to default to --user which installs in PYTHONUSERBASE
  export PIP_USER=yes
  export PYTHONUSERBASE=${HPCTOYS_ROOT}/opt/python
}

# needed if used inside functions
# list all functions with "declare -F"
export -f echoerr
export -f htyInGroup
export -f htyInPath
export -f htyMkdir  
export -f htyAddLineToFile
export -f htyAddLineBelowLineToFile
export -f htyReplaceLineInFile
export -f htyReplaceCommentLineInFile
export -f htyFilesPlain
export -f htyIsItemInList
export -f htyDialogInputbox
export -f htyDialogChecklist
export -f htyReadConfigOrDefault
export -f htyAppendPath
export -f htyPrependPath
export -f htyIntVersion
export -f htyLoadLmod

# GR = root of github repos 
#GR=$(git rev-parse --show-toplevel)
if [[ -n ${BASH_SOURCE} ]]; then 
  GR=$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE}")")")")
else
  echo 'Your shell does not support ${BASH_SOURCE}. Please use "bash" to setup hpctoys.'  
  exit
fi
if [[ -z ${TMPDIR} ]]; then
  export TMPDIR="/tmp"
fi
export HPCTOYS_ROOT="${GR}"
htyMkdir ~/.config/hpctoys
htyMkdir "${HPCTOYS_ROOT}/etc/hpctoys"
WHOAMI=$(whoami)

if [[ "$EUID" -ne 0 ]]; then
  # Security: everyone except app managers should have a umask of 0027 or 0007 
  if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
    umask 0007
  fi
  # Generic Environment variables and PATHs
  if  "${GID_SUPERUSERS}"; then 
    htyAppendPath "${GR}/sbin"
  fi
  htyPrependPath "${GR}/bin" "${GR}/opt/python/bin"
  htyAppendPath "~/.local/bin"
  if [[ -d ${GR}/opt/miniconda ]]; then
    htyAppendPath ${GR}/opt/miniconda/bin
  fi
  
  # replace dark blue color in terminal and VI
  COL=$(htyReadConfigOrDefault "dircolors")
  if [[ -z ${COL} ]]; then
    COL=$(dircolors)
    eval ${COL/di=01;34/di=01;36}
  else
    eval ${COL}
  fi
  
  # *** Spack settings ***
  if [[ -z ${SPACK_ROOT} ]]; then
    export SPACK_ROOT=$(htyReadConfigOrDefault "spack_root")
  fi
  if [[ -n ${SPACK_ROOT} ]]; then 
    initSpack
  fi

  # *** Easybuild Settings 
  initEasybuild "${HPCTOYS_ROOT}/opt/easybuild"
  
  # *** Lmod settings *** 
  export MODULEPATH=${MODULEPATH}:${GR}/opt/eb/modules/all:${GR}/opt/lmod/modules
  export LMOD_MODULERCFILE=${GR}/etc/lmod/rc.lua

  # *** Slurm settings *** 
  # a better format for Slurm's squeue command 
  export SQUEUE_FORMAT="%.18i %.4P %.12j %.8u %.2t %.10M %.10L %.3D %.3C %.9b %.4m %R"

  # *** Podman settings *** 
  if [[ -f /usr/bin/podman ]]; then
    alias docker=podman
  fi
  # This is required for rootless podman services running under systemd
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
fi

