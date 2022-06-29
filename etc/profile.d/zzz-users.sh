# Global settings for all users in your group.
# After   
# git clone https://github.com/dirkpetersen/hpctoys.git
# cd hpctoys
# install.sh


GID_SUPERUSERS=111111
UID_APPMGR=222222
export LPYTHONVER="3.11.0"

# helper functions 
ingroup() { [[ " $(id -G $2) " == *" $1 "* ]]; }   #is user in group (gidNumber)
inpath() { builtin type -P "$1" &> /dev/null ; }   #is executable in path
echoerr() {
  # echo to stderr instead of stdout
  echo -e "$@" 1>&2
}
mkdirIf(){
  # mkdirIf "<dir-name>"
  if ! [[ -d "$1" ]]; then
    mkdir -p  "$1"
  fi
}
addLineToFile() {  
  # addLineToFile <line> <filename>
  if ! grep "^$1" "$2" > /dev/null; then
    echo "$1" >> "$2"
  fi
}
addLineBelowLineToFile() {
  # addLineBelowLineToFile <add-this> <below-this> <filename>
  if ! grep "^$1" "$3" > /dev/null; then
    sed -i "/^$2*/a $1" "$3"
  fi
}
readConfigOrDefault() {
  # readConfigOrDefault <setting> <default>
  if [[ -f ~/.config/hpctoys/$1 ]]; then 
    echo "$(cat ~/.config/hpctoys/$1)"
  elif [[ -f ${HPCTOYS_ROOT}/etc/hpctoys/$1 ]]; then
    echo "$(cat ${HPCTOYS_ROOT}/etc/hpctoys/$1)"
  else 
    echo "$2"
  fi
}
appendPath() {
  for ARG in "$@"; do
    PATH=${PATH//":${ARG}"/} #delete any instances in the middle or at the end
    PATH=${PATH//"${ARG}:"/} #delete any instances at the beginning
    if [[ -d "$ARG" ]]; then  #&& [[ ":$PATH:" != *":$ARG:"* ]]; then
      PATH="${PATH:+"$PATH:"}$ARG"
    fi
  done
}
prependPath() {
  for ((i=$#; i>0; i--)); do
    ARG=${!i}
    PATH=${PATH//":${ARG}"/} #delete any instances in the middle or at the end
    PATH=${PATH//"${ARG}:"/} #delete any instances at the beginning
    if [[ -d "$ARG" ]]; then  #&& [[ ":$PATH:" != *":$ARG:"* ]]; then
      PATH="$ARG${PATH:+":$PATH"}"
    fi
  done
}
intVersion() { 
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; 
}
loadLmod() {
  # capture both STDOUT and STDERR from ml avail 
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

export -f echoerr
export -f initLpython
export -f loadLmod
export -f prependPath
export -f appendPath


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
mkdirIf ~/.config/hpctoys
mkdirIf "${HPCTOYS_ROOT}/etc/hpctoys"
WHOAMI=$(whoami)

if [[ "$EUID" -ne 0 ]]; then
  # Security: everyone except app managers should have a umask of 0027 or 0007 
  if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
    umask 0007
  fi
  # Generic Environment variables and PATHs
  if ingroup "${GID_SUPERUSERS}"; then 
    appendPath "${GR}/sbin"
  fi
  prependPath "${GR}/bin" "~/.local/bin"
  if [[ -d ${GR}/opt/miniconda ]]; then
    appendPath ${GR}/opt/miniconda/bin
  fi 

  # replace dark blue color in terminal and VI
  COL=$(dircolors)
  eval ${COL/di=01;34/di=01;36}
  if ! [[ -f ~/.vimrc ]]; then
    echo -e "syntax on\ncolorscheme desert" > ~/.vimrc
  fi
  
  # *** Spack settings ***
  if [[ -z ${SPACK_ROOT} ]]; then
    export SPACK_ROOT=$(readConfigOrDefault "spack_root")
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

