# Global settings and functions for HPC toys 
# Install HPC Toys: 
#   git clone https://github.com/dirkpetersen/hpctoys.git
#   cd hpctoys
#   ./install.sh
#
# Popular Bashisms for substring:
# NEW=${OLD/search/replacefirst} NEW=${OLD//search/replaceall}
#  * String removal * 
#  PLAINFILE="${URL##*/}" search all / from begin of file
#  TARNOEXT="${TARFILE%%.*}" search all . from end of file 
#  ONLYEXT="${TARFILE#*.}" search first . from begin of file 
# Chop off 1 from: BEGIN=${STR:1}  END=${STR::-1}
# last command argument:  eval last_arg=\$$#

GID_SUPERUSERS=111111
UID_APPMGR=222222
export LPYTHONVER="3.11.0"

# helper functions 
echoerr() {
  # echo to stderr instead of stdout
  echo -e "$@" 1>&2
}
htyInGid() { [[ " $(id -G $2) " == *" $1 "* ]]; }   #is user in group (gidNumber)
htyInGroup() { [[ " $(id -Gn $2) " == *" $1 "* ]]; }   #is user in group (gid)
htyInPath() { builtin type -P "$1" &> /dev/null ; }   #is executable in path
htyInList() { [[ " ${2} " == *" $1 "* ]]; }   #is item in list
htyInCsv() { [[ ",${2}," == *",$1,"* ]]; }   #is item in comma separated list
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
  if [[ $2 == ?(-)+([0-9]) ]] ; then
    if [[ $2 -gt 0 ]]; then
      sleep $2
    elif [[ $2 -eq 0 ]]; then
      read -n 1 -r -s -p $' (Press any key to continue)\n' 
    fi
  elif [[ -n $2 ]]; then
    echo " 2nd argument (sleep-time) must be numeric"
  fi
}

htySpinner() {
  if [[ $1 == ?(-)+([0-9]) ]] ; then
    local -r pid="${1}"
  else
    $@ &
    local -r pid="$!"
  fi
  local -r delay='0.5'
  local spinstr='\|/-'
  local temp
  while ps a | awk '{print $1}' | grep -q "${pid}"; do
    temp="${spinstr#?}"
    printf " [%c]  " "${spinstr}"
    spinstr=${temp}${spinstr%"${temp}"}
    sleep "${delay}"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

htyGitIsInRepos() {
  MSG="${FUNCNAME[0]} <file-or-folder>"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local CURRDIR=$(pwd); local GDIR="${1%+(/)}"

  ! [[ -d "${GDIR}" ]] && GDIR=$(dirname ${GDIR})
  !  [[ -d "${GDIR}" ]] && return 1

  if [[ "${GDIR}" != "${CURRDIR}" ]]; then
    cd "${GDIR}"
    if [[ "${GDIR}" != "$(pwd)" ]]; then
      echoerr " Could not switch to dir ${GDIR}!"
      cd "${CURRDIR}"
      return 1
    fi
  fi

  if git rev-parse 2>/dev/null; then
    cd "${CURRDIR}"
    return 0
  fi
  cd "${CURRDIR}"
  return 1
}

htyGitInitRepos() {
  MSG="${FUNCNAME[0]} <folder>"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local CURRDIR=$(pwd); local GDIR=${1%+(/)}

  if [[ "${GDIR}" != "${CURRDIR}" ]]; then
    cd "${GDIR}"
    if [[ "${GDIR}" != "$(pwd)" ]]; then
      echoerr " Could not switch to dir ${GDIR}!"
      cd "${CURRDIR}"
      return 1
    fi
  fi

  if [[ -z $(git config --global user.name) ]]; then
    echoerr " Global git user not set." 
    echoerr " Re-run HPC Toys installer."
    cd "${CURRDIR}"
    return 1      
  fi
  
  if ! [[ -f README.md ]]; then
    echo "# Repository $(basename ${GDIR})" \
        > README.md
  fi
  if ! [[ -f .gitignore ]]; then
    echo "*__pycache__*" > .gitignore
  fi
 
  git init
  git symbolic-ref HEAD refs/heads/main
  git add -A .
  git commit -a -m "Initial commit"  

  cd "${CURRDIR}"

}

htyGithubInitRepos() {
  MSG="${FUNCNAME[0]} <user-org/repos> <folder>"
  [[ -z $2 ]] && echo ${MSG} && return 1
  local CURRDIR=$(pwd); local GDIR=${2%+(/)}; local ERR=0

  if [[ "${GDIR}" != "${CURRDIR}" ]]; then
    cd "${GDIR}"
    if [[ "${GDIR}" != "$(pwd)" ]]; then
      echoerr " Could not switch to dir ${GDIR}!"
      cd "${CURRDIR}"
      return 1
    fi
  fi

  if [[ -z $(git config --global user.name) ]]; then
    echoerr " Global git user not set."
    echoerr " Re-run HPC Toys installer."
    cd "${CURRDIR}"
    return 1
  fi

  if ! git rev-parse 2>/dev/null; then
     cd "${CURRDIR}"
     echoerr " ${GDIR} is not a git repository"
     return 1
  fi

  MYREPOS=$(htyRemoveTrailingSlashes $1)

  if ! git ls-remote git@github.com:${MYREPOS}.git; then
     echoerr " Error listing github.com:${MYREPOS} !"
     return 1 
  fi

  git remote add origin git@github.com:${MYREPOS}.git
  [[ $? -gt 0 ]] && ERR=1
  git remote -v
  [[ $? -gt 0 ]] && ERR=1
  git push --set-upstream origin main
  [[ $? -gt 0 ]] && ERR=1
  cd "${CURRDIR}"
  return ${ERR}
}

htyIncrementTrailingNumber() {
  MSG="${FUNCNAME[0]} <string-with-trailing-num>"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local LASTINT; local BASE
  if [[ $1 =~ ([0-9]+)[^0-9]*$ ]]; then
    LASTINT=${BASH_REMATCH[1]}
    BASE=${1%${LASTINT}}
    let LASTINT++
    printf "${BASE}${LASTINT}"
    return 0
  else
    printf "${1}"
  fi
  return 0
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

htyRemoveTrailingSlashes() {
  local MYPATH=$1
  MYPATH=${MYPATH%+(/)} #remove slash from end 
  MYPATH=${MYPATH#+(/)} #remove slash from beginning
  MYPATH=${MYPATH%+(/)} #remove slash from end
  MYPATH=${MYPATH#+(/)} #remove slash from beginning
  echo ${MYPATH}
}

htyFilesFull() {
  MSG="${FUNCNAME[0]} <folder> [file-or-wildcard] [max-entries]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  htyFilesPlain "$1" "$2" "$3" "full"
}

htyFilesPlain() {
  MSG="${FUNCNAME[0]} <folder> [file-or-wildcard] [max-entries] [include-full-path]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local FLD
  eval FLD="$1"
  local MYPAT="*"
  local MYMAX="tee"
  [[ -n $2 ]] && MYPAT="$2"
  [[ $3 -gt 0 ]] && MYMAX="head -n $3"
  if [[ -z $4 ]]; then
    find "${FLD}" -maxdepth 1 \( -type f -o -type l \) \
            -iname "${MYPAT}" -printf "%f\n" \
            | grep -v '^\.' \
            | sort --ignore-case | ${MYMAX}
  else
    find "${FLD}" -maxdepth 1 \( -type f -o -type l \) \
            -iname "${MYPAT}" \
            | grep -v '/\.' \
            | sort --ignore-case | ${MYMAX}
  fi
}

htyDialogError() {
  MSG="${FUNCNAME[0]} \"<return-code>\" \"<error-message>\""
  [[ -z $1 ]] && echo ${MSG} && return 1
  if [[ $1 -eq 255 ]]; then
    if [[ -z ${2} ]]; then
      echoerr "Canceled (Esc)!"
    elif [[ "$2" =~ "Can't make sub-window" ]]; then 
      echoerr "Your terminal is too small" 
      echoerr "Please increase window size. Error: $2"
    else 
      echoerr "Other Error (255): $2"
    fi
  elif [[ $1 -gt 1 ]]; then
    echoerr "Error $1:"
    echoerr "$2"
  elif [[ $1 -eq 1 ]]; then
    echoerr "Canceled!"
    echo "$2"
  fi
  RES=""
  #htyEcho "$1 $2" 0
}

htyFileSelMulti() {
  MSG="${FUNCNAME[0]} <message> <folder> [file-or-wildcard] [max-entries] [default-file]"
  [[ -z $2 ]] && echo ${MSG} && return 1
  DIALOGTYPEX="--checklist"
  htyFileSel "$@"
}


htyFileSel() {
  # will display unicode strangely, e.g Umlaut-ä-ü-ö-ß-Code.py
  MSG="${FUNCNAME[0]} <message> <folder> [file-or-wildcard] [max-entries] [default-entry]"
  [[ -z $2 ]] && echo ${MSG} && return 1
  local RET=""; local DEF="" ; local MAXENT=0
  local OPT=(); local MYFILES; local DIALOGRC
  export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
  # make array from last 25 lines in reverse order
  [[ -n $4 ]] && MAXENT=$4
  readarray -n ${MAXENT} -t MYFILES < <(htyFilesPlain "$2" "$3")
  OPT=() # options array
  RES=""
  i=0
  DEF=$5
  ONOFF="off"
  if [[ -z ${DIALOGTYPEX} ]]; then
    DIALOGTYPEX="--menu"
    ONOFF=""
  fi
  if [[ -n "${DEF}" ]]; then
    HASDEF=""
    for FIL in "${MYFILES[@]}"; do
      if [[ "${FIL}" == "${DEF}" ]]; then
        HASDEF="${FIL}"
      fi
    done
    # if we passed in a default that is not in 
    # the list of files we just add this entry
    # to the top.
    # This can be used to create a new file or 
    # it can simply be a command such as 
    # create-new-file.
    if [[ -z "${HASDEF}" ]]; then
       OPT+=("${DEF}" "" ${ONOFF})
    fi
  fi
  for FIL in "${MYFILES[@]}"; do
    [[ -z ${DEF} ]] && DEF=${FIL}
    OPT+=("${FIL}" "" ${ONOFF})
  done
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --backtitle "HPC Toys" \
                 --title "HPC Toys" \
                 --default-item "${DEF}" \
                 ${DIALOGTYPEX} "$1" 0 0 0 "${OPT[@]}" \
                 3>&2 2>&1 1>&3-  #2>&1 1>/dev/tty
                 )
    RET=$?
    if [[ ${RET} -ne 0 ]]; then
      htyDialogError "${RET}" "${RES}"
      unset DIALOGTYPEX
      return ${RET}
    fi
  done
  #htyEcho "X${RES}X" 0
  unset DIALOGTYPEX
}

htyFolderSel() {
  MSG="${FUNCNAME[0]} <message> [default-folder] [title]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local MYCFG=~/.config/hpctoys/foldersel
  local MYAWCFG=~/.config/hpctoys/foldersel_always
  local RET=""; local DEF=""; local TITLE=""
  local OPT=(); local MYFLDS; local DIALOGRC 
  export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
  # make array from last 25 lines in reverse order
  readarray -n 25 -t MYFLDS < <(tac ${MYCFG})
  MYAW=$(htyReadConfigOrDefault "${MYAWCFG}" '-')
  RES='loop'
  TITLE="Select Folder"
  [[ -n $3 ]] && TITLE="$3"
  while [[ "$RES" == "loop" ]]; do
    if [[ -n $2 ]]; then
      OPT+=("$2" "")
      [[ -z ${DEF} ]] && DEF="$2"
    fi
    OPT+=("." "(current dir)")
    OPT+=("/" "(root)")
    OPT+=("~" "(home)")   
    M="always use browser"
    if [[ ${MYAW} == "-" ]]; then
      M="browser for / and ~"
    fi 
    OPT+=("  select always (${MYAW})" "$M")
    for FLD in "${MYFLDS[@]}"; do 
      [[ -z ${DEF} ]] && DEF=${FLD}
      OPT+=("${FLD}" "")    
    done
    RES=$(dialog --backtitle "HPC Toys" \
	       --title "${TITLE} ($M)" \
               --default-item "${DEF}" \
	       --menu "$1" 0 0 0 "${OPT[@]}" \
	       3>&2 2>&1 1>&3-  # 2>&1 1>/dev/tty 
             )
    RET=$?
    OPT=()
    if [[ ${RET} -ne 0 ]]; then
      htyDialogError "${RET}" "${RES}"
      return ${RET}
    fi
    if [[ ${RES} == "  select always"* ]]; then
      [[ ${MYAW} == "X" ]] && MYAW="-" || MYAW="X"
      printf "${MYAW}" > ${MYAWCFG}
      DEF="  select always (${MYAW})"
      RES="loop"
    fi
  done
  if [[ ${#RES} -eq 1 ]] || [[ ${MYAW} == "X" ]]; then
    # if single char (/ or ~) or globally enabled
    eval RES="${RES}" # expand ~
    RES=$(foldersel "${RES}")
    H=$(echo ~) # get true homedir
    if [[ $RES == "$H"* ]]; then
      RES=${RES/$H/'~'}
    fi
  fi
  RESI=${RES//\//\\\/} # escape all slashes for sed
  sed -i '/^'"${RESI}"'$/d' ~/.config/hpctoys/foldersel
  if [[ ${#RES} -gt 1 ]]; then 
    echo "${RES}" >> ~/.config/hpctoys/foldersel
  fi
  #printf "${RES}"
return 0
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
  MSG="${FUNCNAME[0]} <message> [default-value] [box-title]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local RET; local MYTIT
  local DIALOGRC && export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
  [[ -z $3 ]] && MYTIT="HPC Toys" || MYTIT=$3
  RES="" 
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --backtitle "HPC Toys" \
                 --title "${MYTIT}" \
                 --inputbox "$1" 0 0 "$2" \
                 3>&2 2>&1 1>&3-  #2>&1 1>/dev/tty
                 )
    RET=$?
    #echo $RET:$RES && sleep 3
    if [[ ${RET} -ne 0 ]]; then
      htyDialogError "${RET}" "${RES}"
      return ${RET}
    fi 
    if [[ -z "$2" ]] && [[ -z "${RES}" ]]; then 
      # RES = "" is allowed only if default was ""
      return 0
    fi
  done  
}

htyDialogYesNo() {
  # wrapper for unix dialog --yesno
  MSG="${FUNCNAME[0]} <message> [box-title]"
  [[ -z $1 ]] && echo ${MSG} && return 1
  local RET; local MYTIT
  local DIALOGRC && export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
  [[ -z $2 ]] && MYTIT="HPC Toys" || MYTIT=$2
  RES=""
  RES=$(dialog --backtitle "HPC Toys" \
	       --title "${MYTIT}" \
	       --yesno "$1" 0 0 \
	       3>&2 2>&1 1>&3-  #2>&1 1>/dev/tty
	       )
  RET=$?
  case $RET in
     0) 
        RES="Yes"
        ;;
     1) 
        RES="No"
        ;;
     255) 
        echo "[ESC] key pressed .. exiting."
        RES=""
        exit 
        ;;
     *)
       htyDialogError "${RET}" "${RES}"
       return  ${RET}
       ;;
   esac
}




htyDialogChecklist() {
  # wrapper for unix dialog --checklist
  #read -n 1 -r -s -p $"\n  $1 $2 $3 Press enter to continue...\n"
  MSG="${FUNCNAME[0]} <message> <list-of-options> <selected-options> [box-title]"
  [[ -z $2 ]] && echo ${MSG} && return 1
  local MYTIT; local DIALOGRC && export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc  
  [[ -z $4 ]] && MYTIT="HPC Toys" || MYTIT=$4
  OPT=()
  RES=""
  i=0
  DEF=""
  for E in $2; do 
    let i++
    if [[ " $3 " =~ .*\ ${E}\ .* ]]; then
      OPT+=("${E}" "" on) # or "$i" "on"
      [[ -z ${DEF} ]] && DEF=$E
    else
      OPT+=("${E}" "" off) 
    fi
  done
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --backtitle "HPC Toys" \
                 --title "${MYTIT}" \
                 --default-item "${DEF}" \
                 --checklist "$1" 0 0 0 "${OPT[@]}" \
                 3>&2 2>&1 1>&3-  #2>&1 1>/dev/tty
                 ) 
    RET=$?
    if [[ ${RET} -ne 0 ]]; then
      htyDialogError "${RET}" "${RES}"
      return ${RET}
    fi
  done
  clear
}

htyDialogMenu() {
  # wrapper for unix dialog --menu
  #read -n 1 -r -s -p $"\n  $1 $2 $3 Press enter to continue...\n"
  MSG="${FUNCNAME[0]} <message> <list-of-options> <default-option> [box-title]"
  [[ -z $2 ]] && echo ${MSG} && return 1
  local MYTIT; local DIALOGRC && export DIALOGRC=${HPCTOYS_ROOT}/etc/.dialogrc
  [[ -z $4 ]] && MYTIT="HPC Toys" || MYTIT=$4
  OPT=() # options array
  RES=""
  i=0
  DEF=$3
  for E in $2; do
    let i++
    if [[ $E == *'*' ]]; then # slurm defaults show as *
      DEF=${E:0:-1}
      E=${DEF}
    fi
    OPT+=("${E}" "") # or "$i"
    [[ -z ${DEF} ]] && DEF="$E"
  done
  while [[ "$RES" == "" ]]; do
    RES=$(dialog --backtitle "HPC Toys" \
                 --title "$MYTIT" \
                 --default-item "${DEF}" \
                 --menu "$1" 0 0 0 "${OPT[@]}" \
                 3>&2 2>&1 1>&3-  #2>&1 1>/dev/tty
                 )
    RET=$?
    if [[ ${RET} -ne 0 ]]; then
      htyDialogError "${RET}" "${RES}"
      return ${RET}
    fi
  done
  clear
}

### More dialogs 
#dialog --yesno "Is it yes or no?" 0 0
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

htySlurmTime2Sec() {
  local STIME="$1"; local DAYS_HOURS; local DAYS
  local PART_DAYS; local HMS
  
  if [[ $STIME == *-* ]]; then
    IFS='-' read -ra DAYS_HOURS <<< $STIME
    DAYS=${DAYS_HOURS[0]}
    PART_DAYS=${DAYS_HOURS[1]}
  else
    DAYS=""
    PART_DAYS=$STIME
  fi
  if [[ $PART_DAYS == *:*:* ]]; then
    IFS=':' read -ra HMS <<< $PART_DAYS
    H=${HMS[0]}
    M=${HMS[1]}
    S=${HMS[2]}
  elif [[ $PART_DAYS == *:* ]]; then
    IFS=':' read -ra HMS <<< $PART_DAYS
    H=0
    M=${HMS[0]}
    S=${HMS[1]}
  else 
    if [[ -z ${DAYS} ]]; then
      H=0
      M=$PART_DAYS
      S=0
    else
      H=$PART_DAYS
      M=0
      S=0
    fi
  fi
  [ -z ${DAYS} ] && DAYS=0

  #SECONDS=`echo "((($DAYS*24+$H)*60+$M)*60+$S)" | bc`
  #echo Time limit: $SECONDS seconds
  #HOURS=`echo "scale=3;((($DAYS*24+$H)*60+$M)*60+$S)/3600." | bc`
  #echo Time limit: $HOURS hours

  echo "((($DAYS*24+$H)*60+$M)*60+$S)" | bc
}

initSpack(){
  # initSpack 
  if [[ -d "${SPACK_ROOT}" ]]; then
    source ${SPACK_ROOT}/share/spack/setup-env.sh
    if ! [[ -f  "${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash" ]]; then
      printf "configure Spack environment ... "
      echo "${SPACK_ROOT}" > \
              ${HPCTOYS_ROOT}/etc/hpctoys/spack_root

      echo "$(spack location -i lmod)/lmod/lmod/init/bash" > \
              ${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash
      echo "Done!"
    fi
    source $(cat "${HPCTOYS_ROOT}/etc/hpctoys/spack_lmod_bash")
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
if [[ -n "${BASH}" ]]; then
  export -f echoerr
  export -f htyInGid
  export -f htyInGroup
  export -f htyInList
  export -f htyInCsv
  export -f htyInPath
  export -f htyMkdir 
  export -f htyEcho
  export -f htySpinner
  export -f htyGitIsInRepos
  export -f htyGitInitRepos
  export -f htyGithubInitRepos
  export -f htyIncrementTrailingNumber
  export -f htyAddLineToFile
  export -f htyAddLineBelowLineToFile
  export -f htyReplaceLineInFile
  export -f htyCommentAndReplaceLineInFile
  export -f htyRemoveTrailingSlashes
  export -f htyFilesPlain
  export -f htyFilesFull
  export -f htyFileSel
  export -f htyFolderSel
  export -f htyIsItemInList
  export -f htyDialogInputbox
  export -f htyDialogChecklist
  export -f htyDialogMenu
  export -f htyDialogYesNo
  export -f htyReadConfigOrDefault
  export -f htyAppendPath
  export -f htyPrependPath
  export -f htyRootCheck
  export -f htySlurmTime2Sec
  export -f htyInstallSource
  export -f htyDownloadUntarCd
  export -f htyConfigureMakeInstall
  export -f htyIntVersion
  export -f htyLoadLmod
fi

########## Setting HPC Toys Environment ################################
# GR = root of github repos 
#GR=$(git rev-parse --show-toplevel)

MYBASHVER=${BASH_VERSION:0:3}
if [[ -z ${BASH} ]]; then 
  echoerr " HPC Toys only works with Bash, sorry !"  
  return 1  
elif [[ "${MYBASHVER/./}" -lt 42 ]]; then
  echoerr " HPC Toys only works with Bash >= 4.2, sorry !"
  return 1
fi

GR=$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE}")")")")
export HPCTOYS_ROOT="${GR}"
if [[ -z ${TMPDIR} ]]; then
  export TMPDIR="/tmp"
fi
htyMkdir ~/.config/hpctoys
htyMkdir "${HPCTOYS_ROOT}/etc/hpctoys"
WHOAMI=$(whoami)

if [[ "$0" != "-bash" ]]; then
 return 0 # only read the below if sourced in Shell
fi 

if [[ "$(id -u)" -eq 0 ]]; then
 return 0 # the below is only for non-root users
fi 


# Security: everyone except app managers should have a umask of 0027 or 0007 
if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
  umask 0007
fi

# *** Spack settings ***
if [[ -z ${SPACK_ROOT} ]]; then
  export SPACK_ROOT=$(htyReadConfigOrDefault "spack_root")
fi
if [[ -n ${SPACK_ROOT} ]]; then
  initSpack
fi

# Generic Environment variables and PATHs
if htyInGid ${GID_SUPERUSERS}; then 
  htyAppendPath "${GR}/sbin"
fi
htyPrependPath "${GR}/bin" 
htyPrependPath ~/.local/bin
htyAppendPath ~/bin
if [[ -d ${GR}/opt/miniconda ]]; then
  htyAppendPath ${GR}/opt/miniconda/bin
  # get the default python for hpctoys
  PY=$(ls -t ${GR}/opt/miniconda/bin/python3.?? 2>/dev/null | head -1)
  [[ -x ${PY} ]] && export HTY_PYTHON=$PY && export EB_PYTHON=$PY
fi

# training wheels wait time in seconds. 0 requires confirm
export TWW=$(htyReadConfigOrDefault "training-wheels-wait")

# replace dark blue color in terminal and VI
COL=$(htyReadConfigOrDefault "dircolors")
if [[ -z ${COL} ]]; then
  COL=$(dircolors)
  eval ${COL/di=01;34/di=01;36}
else
  eval ${COL}
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

# Show a help message after login  
if [[ -z "$(htyReadConfigOrDefault "quiet")" ]]; then
  htyEcho "run 'hpctoys' to show menu or" 
  htyEcho "'hty quiet' to stop this message"
fi


