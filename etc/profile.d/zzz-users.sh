# Global settings for all users in your group.
# After   
# git clone https://github.com/dirkpetersen/hpctoys.git
# cd hpctoys
# install.sh

GID_SUPERUSERS=111111
UID_APPMGR=222222

ingroup(){ [[ " $(id -G $2) " == *" $1 "* ]]; }   #is user in group (gidNumber)
inpath(){ builtin type -P "$1" &> /dev/null ; }   #is executable in path

# GR = root of github repos 
#GR=$(git rev-parse --show-toplevel)
if [[ -n ${BASH_SOURCE} ]]; then 
  GR=$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE}")")")")
else
  echo 'Your shell does not support ${BASH_SOURCE}. Please use "bash" to setup hpctoys.'  
  exit
fi
export HPCTOYS_ROOT=${GR}

if [[ "$EUID" -ne 0 ]]; then
  # Security: everyone except app managers should have a umask of 0027 or 0007 
  if [[ "$EUID" -ne ${UID_APPMGR} ]]; then 
    umask 0007
  fi
  if ingroup "${GID_SUPERUSERS}"; then 
    export PATH=$PATH:${GR}/sbin
  fi
  # Generic Environment variables 
  export PATH=${GR}/bin:~/.local/bin:${GR}/opt/python/bin:${PATH}
  if [[ -d ${GR}/opt/miniconda ]]; then
    export PATH=${PATH}:${GR}/opt/miniconda/bin
  fi 
  if ! [[ -d ~/.config/hpctoys ]]; then
    mkdir -p  ~/.config/hpctoys
  fi 
  
  # *** Spack settings ***
  if [[ -d /home/exacloud/software/spack ]]; then 
    export SPACK_ROOT=/home/exacloud/software/spack
    . ${SPACK_ROOT}/share/spack/setup-env.sh
    if ! [[ -f  ~/.config/hpctoys/spack_lmod_bash ]]; then 
       printf "configure Spack environment ... "
       echo "$(spack location -i lmod)/lmod/lmod/init/bash" > ~/.config/hpctoys/spack_lmod_bash
       echo "Done!"
    fi 
    . $(cat ~/.config/hpctoys/spack_lmod_bash)
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

