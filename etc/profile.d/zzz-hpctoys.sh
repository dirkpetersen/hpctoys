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
htyEcho() {
  MSG="${FUNCNAME[0]} <colored-msg> [sleep-time]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  if htyInPath "tput"; then
    COLEND=""
    COLRED=""
    COLYEL=""
    if test -t 1;then
      NCOL=$(tput colors)
      if test -n "$NCOL" && test $NCOL -ge 4; then
        COLEND=$(tput sgr0) # reset the foreground colour
        COLRED=$(tput setaf 1)
        COLYEL=$(tput setaf 3)
      fi
    fi
    echo -e " ${COLYEL}$1${COLEND}" 1>&2
  else
    echo -e "$1" 1>&2
  fi
  if test -n $2; then 
    if [[ $2 -gt 0 ]]; then
      sleep $2
    fi
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
  MSG="${FUNCNAME[0]} <below-this> <replacement-line> <file-that-exists>"
  [[ ! -f $3 ]] && echo ${MSG} && return 1
  if ! grep -q "^$2" "$3"; then
    sed -i '/^'"${1}"'.*/a '"${2}" "$3"
  fi
}
htyReplaceLineInFile() {
  MSG="${FUNCNAME[0]} <line-to-be-replaced> <replacement-line> <file-that-exists>"
  [[ ! -f $3 ]] && echo ${MSG} && return 1
  if ! grep -q "^$2" "$3"; then
    sed -i 's|^'"${1}"'.*|'"${2}"'|g' "$3"
  fi
}
htyCommentAndReplaceLineInFile() {
  MSG="${FUNCNAME[0]} <line-to-be-commented> <replacement-line> <file-that-exists>"
  [[ ! -f $3 ]] && echo ${MSG} && return 1
  if ! grep -q "^$2" "$3"; then
    sed -i 's|^'"${1}"'|#'"${1}"'|g' "$3"
    sed -i '/^\#'"${1}"'.*/a '"${2}" "$3"
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
      RES=""
      echoerr "\n  htyDialogInputbox canceled  ...\n"
      return 1
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
      RES=""
      echoerr "\n  htyDialogChecklist canceled  ...\n"
      return 1
    fi
  done
  clear
}

htyDialogMenu() {
  # wrapper for unix dialog --menu
  #read -n 1 -r -s -p $"\n  $1 $2 $3 Press enter to continue...\n"
  MSG="${FUNCNAME[0]} <message> <list-of-options>"
  [[ -z $2 ]] && echo ${MSG} && return 1
  OPT=""
  RES=""
  i=0
  for E in $2; do
    let i++
    OPT+="$E $i "
  done
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --menu "$1" 0 0 0 ${OPT} 2>&1 1>/dev/tty)
    RET=$?
    #echo $RET:$RES && sleep 3
    if [[ $RET -ne 0 ]]; then
      clear
      RES=""
      echoerr "\n  htyDialogMenu canceled ...\n"
      return 1
    fi
  done
  clear
}

### More dialogs 
#dialog --pause "This is a 30 second pause" 0 0 30
#dialog --menu "Choose the option" 12 45 25 1 "apple" 2 "banana" 3 "mango"
#dialog --radiolist "radiolist" 15 10 10 "apple" 5 'off' 'banana' 2 'off' 'coffee' 3 'off'

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
    ml $(printf "${AVAIL}" | grep -i "^${M}" | tail -1)
  done
}

htyInstallSource() {
  # will create a tmpdir in ramdisk
  # and run both htyDownloadUntarCd
  # and htyConfigureMakeInstall fully
  # automated 
  MSG="${FUNCNAME[0]} <url> [prefix_options] [cmd]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  ! htyRootCheck && return 1
  MYTMP="/dev/shm/$(whoami)"
  mkdir -p ${MYTMP}
  [[ ! -d ${MYTMP} ]] && MYTMP="/dev/shm" 
  [[ -z ${INTMP} ]] && INTMP=$(mktemp -d "${MYTMP}/hpctoys.XXX")
  cd ${INTMP}
  if htyDownloadUntarCd "$1"; then
    if htyConfigureMakeInstall "$2" "$3"; then
      htyEcho "App was installed from ${INTMP}"
    else 
      return 1
    fi
  else 
    return 1
  fi
  return 0
}

htyDownloadUntarCd() {
  # will download and untar the URL in build DIR 
  # and cd to that build dir, requires ${INTMP} 
  # and ${ERRLIST} to be set   
  MSG="${FUNCNAME[0]} <url> [cd-prefix]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  ! htyRootCheck && return 1
  DURL="$1"
  TARFILE="${DURL##*/}"
  BASENAME="${TARFILE%%.tar*}"
  # get left of first dash in filename or else first dot
  [[ ${BASENAME} == ${TARFILE} ]] && BASENAME="${TARFILE%%.tgz}"
  APPNAME="${TARFILE%%-*}"
  # get left of first dash in filename or else first dot 
  [[ ${APPNAME} == ${TARFILE} ]] && APPNAME="${TARFILE%%.*}"
  htyEcho "\n* Downloading ${APPNAME} ... *\n"
  sleep 1
  [[ -n ${INTMP} ]] && cd ${INTMP}
  curl -OkL ${DURL}
  if [[ -f ${TARFILE} ]]; then
    htyEcho "untarring ${TARFILE}"    
    tar xf ${TARFILE}
    mkdir -p tarballs
    mv -f ${TARFILE} ./tarballs/
    if [[ -n $2 ]]; then
      htyEcho "cd $2${BASENAME}"
      cd $2${BASENAME}
    else
      htyEcho "cd ${BASENAME}"
      cd ${BASENAME}
    fi
    if [[ "$?" -ne 0 ]]; then
      # 5 chars should be enough for a quess
      cd "${BASENAME:0:5}"*
      if [[ "$?" -ne 0 ]]; then
        ERRLIST+=" ${BASENAME}"
        return 1 
      fi
    fi
  else 
    htyEcho "unable to download ${DURL}, exiting !"
    ERRLIST+=" ${BASENAME}"
    return 1 
  fi
  htyEcho "current directory: $(pwd)"
  return 0
}

htyConfigureMakeInstall(){
  # will configure; make; make install
  # if prefix_options is given it will not 
  # use the default prefix opt/other, if 
  # cmd is given it creates a symlink in bin.
  # uses ${CURRDIR} and ${RUNCPUS} if set.
  # Start dir is the untar dir under the 
  # current dir or under ${INTMP} if set
  # example:
  # htyConfigureMakeInstall opt/test bin/test
  MSG="${FUNCNAME[0]} [prefix_options] [cmd]"
  ! htyRootCheck && return 1
  MYAPP=$(basename $(pwd))
  if [[ ! -f ./configure ]]; then  
    htyEcho "./configure script not found" 
    ERRLIST+=" ${MYAPP}"
    return 1
  fi
  MYDIR='${HPCTOYS_ROOT}/opt/other'
  MYPRE='--prefix '"${MYDIR}"
  if [[ -n $1 ]]; then 
    MYDIR=$(printf $1 | cut -d ' ' -f1)
    MYPRE='--prefix ${HPCTOYS_ROOT}/'"$1"
  fi
  ./configure ${MYPRE}  2>&1 | tee output.configure.out
  if [[ "$?" -ne 0 ]]; then
    htyEcho "${MYAPP}: Error running ./configure ${MYPRE}"
    ERRLIST+=" ${MYAPP}"
    return 1
  else
    htyEcho "${MYAPP}: ./configure successful ${MYPRE}"
    sleep 1
  fi
  MYCPUS=4
  [[ -n ${RUNCPUS} ]] && MYCPUS=${RUNCPUS}
  make clean
  make -j ${MYCPUS} 2>&1 | tee output.make.out
  if [[ "$?" -ne 0 ]]; then
    htyEcho "${MYAPP}: Error running  make -j ${MYCPUS}"
    ERRLIST+=" ${MYAPP}"
    return 1
  else 
    htyEcho "${MYAPP}: compile successful: make -j ${MYCPUS}"
    sleep 1
  fi
  make install 2>&1 | tee output.make.install.out
  if [[ "$?" -ne 0 ]]; then
    htyEcho "${MYAPP}: Error running make install"
    ERRLIST+=" ${MYAPP}"
    return 1
  else
    htyEcho "${MYAPP}: make install successful !"
  fi
  if [[ -n $2 ]]; then
    echoerr " trying to create symlink to $2"
    if [[ -f ${HPCTOYS_ROOT}/${MYDIR}/$2 ]]; then
      MYBIN=$(basename $2)
      ln -sfr "${HPCTOYS_ROOT}/${MYDIR}/$2" "${HPCTOYS_ROOT}/bin/${MYBIN}"
      if [[ "$?" -eq 0 ]]; then 
        htyEcho "created sympolic link ${HPCTOYS_ROOT}/bin/${MYBIN}"
        htyEcho "pointing to ${HPCTOYS_ROOT}/${MYDIR}/$2"
      else
        htyEcho "failed creating sympolic link bin/${MYBIN}"
        ERRLIST+=" ${MYAPP}"
        return 1
      fi
    else
      htyEcho "Binary does not exist: ${HPCTOYS_ROOT}/${MYDIR}/$2"
      ERRLIST+=" ${MYAPP}"
      return 1
    fi
  fi
  [[ -n ${CURRDIR} ]] && cd ${CURRDIR}
  return 0
}

htyRootCheck() {
  if [[ -z ${HPCTOYS_ROOT} ]]; then
    htyEcho "\n The HPCTOYS_ROOT environment variable is not"
    htyEcho "set. Please re-run the HPC Toys install.sh script"
    htyEcho "or run 'source etc/profile.d/zzz-hpctoys.sh at"
    htyEcho "the root of a HPC toys git repository.\n"
    return 1
  fi
  if ! [[ -d ${HPCTOYS_ROOT} ]]; then
    htyEcho "HPCTOYS_ROOT directory ${HPCTOYS_ROOT} does not exist."
    return 1 
  fi
  return 0
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
export -f htyEcho 
export -f htyAddLineToFile
export -f htyAddLineBelowLineToFile
export -f htyReplaceLineInFile
export -f htyCommentAndReplaceLineInFile
export -f htyFilesPlain
export -f htyIsItemInList
export -f htyDialogInputbox
export -f htyDialogChecklist
export -f htyDialogMenu
export -f htyReadConfigOrDefault
export -f htyAppendPath
export -f htyPrependPath
export -f htyRootCheck
export -f htyInstallSource
export -f htyDownloadUntarCd
export -f htyConfigureMakeInstall
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
  if htyInGroup ${GID_SUPERUSERS}; then 
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

