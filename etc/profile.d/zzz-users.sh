# Global settings for all users in your group.
# After   
# git clone https://github.com/dirkpetersen/hpctoys.git
# cd hpctoys
# install.sh

GID_SUPERUSERS=111111
UID_APPMGR=222222

ingroup(){ [[ " $(id -G $2) " == *" $1 "* ]]; }   #is user in group (gidNumber)
inpath(){ builtin type -P "$1" &> /dev/null ; }   #is executable in path
GR=$(git rev-parse --show-toplevel)

if [[ "$EUID" -ne 0 ]]; then
  # Security: everyone except app managers should have a umask of 0027 or 0007 
  if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
    umask 0027
  fi
  if ingroup "${GID_SUPERUSERS}"; then 
    export PATH=$PATH:${GR}/sbin
  fi
  # Generic Environment variables 
  export PATH=$PATH:${GR}/bin
  
  # *** Lmod settings *** 
  export MODULEPATH=$MODULEPATH:${GR}/local/eb/modules/all:${GR}/local/other/modules
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

