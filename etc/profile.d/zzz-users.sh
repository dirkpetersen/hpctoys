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
    return "$(cat ~/.config/hpctoys/$1)"
  elif [[ -f ${HPCTOYS_ROOT}/etc/hpctoys/$1 ]]; then
    return "$(cat ${HPCTOYS_ROOT}/etc/hpctoys/$1)"
  else 
    return "$2"
  fi
}
intVersion() { 
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; 
}
loadLmod() {
  # capture both STDOUT and STDERR from ml avail 
  if [[ -z $1 ]]; then
    echo "please enter start of your module names, e.g. gcc libffi"
    return
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
    tar xf ${PYARCHIVE} -C "${TMPDIR}/hpctoys"
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

if [[ "$EUID" -ne 0 ]]; then
  # Security: everyone except app managers should have a umask of 0027 or 0007 
  if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
    umask 0007
  fi
  if ingroup "${GID_SUPERUSERS}"; then 
    export PATH=$PATH:${GR}/sbin
  fi
  # Generic Environment variables 
  export PATH=${GR}/bin:~/.local/bin:${PATH}
  if [[ -d ${GR}/opt/miniconda ]]; then
    export PATH=${PATH}:${GR}/opt/miniconda/bin
  fi 
  if ! [[ -d ~/.config/hpctoys ]]; then
    mkdir -p  ~/.config/hpctoys
  fi

  # replace dark blue color in terminal and VI
  COL=$(dircolors)
  eval ${COL/di=01;34/di=01;36}
  if ! [[ -f ~/.vimrc ]]; then
    echo -e "syntax on\ncolorscheme desert" > ~/.vimrc
  fi
  
  # *** Spack settings ***
  if [[ -d /home/exacloud/software/spack ]]; then 
    export SPACK_ROOT=/home/exacloud/software/spack
    . ${SPACK_ROOT}/share/spack/setup-env.sh
    if ! [[ -f  ~/.config/hpctoys/spack_lmod_bash ]]; then 
       echo "Spack environment not setup, run hpctoys installer... "
    else 
       . $(cat ~/.config/hpctoys/spack_lmod_bash)
    fi
  fi
  # Easybuild Settings 
  EASYBUILD_JOB_CORES=4
  EASYBUILD_CUDA_COMPUTE_CAPABILITIES=7.5,8.0,8.6,9.0
  EASYBUILD_BUILDPATH=/dev/shm/scicompappsvc
  EASYBUILD_PREFIX=/app/eb
  EASYBUILD_JOB_OUTPUT_DIR=/app/eb/slurm-output
  EASYBUILD_JOB_BACKEND=Slurm
  EASYBUILD_PARALLEL=16
  EASYBUILD_GITHUB_USER=scicomp-moffitt
  EASYBUILD_UPDATE_MODULES_TOOL_CACHE=True
  #EASYBUILD_ROBOT_PATHS=/home/scicompappsvc/.local/easybuild/easyconfigs:/app/eb/fh/fh_easyconfigs/:/app/eb/mcc/mcc_easyconfigs/

  
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

