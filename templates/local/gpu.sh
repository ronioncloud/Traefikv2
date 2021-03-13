#!/bin/bash
#
# Title:      LSPCI || IGPU & NVIDIA GPU
# Author(s):  mrdoob
# URL:        https://sudobox.io/
# GNU:        General Public License v3.0
################################################################################
DREA=$(pidof dockerd 1>/dev/null 2>&1 && echo true || echo false)
CHKN=$(ls /usr/bin/nvidia-smi 1>/dev/null 2>&1 && echo true || echo false)
DCHK=$(cat /etc/docker/daemon.json | grep -qE 'nvidia' && echo true || echo false)
RCHK=$(ls /etc/apt/sources.list.d/ 1>/dev/null 2>&1 | grep -qE 'nvidia' && echo true || echo false)
HMOD=$(ls /etc/modprobe.d/ | grep -qE 'hetzner' && echo true || echo false)
ITEL=$(cat /etc/modprobe.d/blacklist-hetzner.conf | grep -qE '#blacklist i915' && echo true || echo false)
IMOL=$(cat /etc/default/grub | grep -qE '#GRUB_CMDLINE_LINUX_DEFAULT' && echo true || echo false)
GVID=$(id $(whoami) | grep -qE 'video' && echo true || echo false)
GCHK=$(grep -qE video /etc/group && echo true || echo false)
DEVT=$(ls /dev/dri 1>/dev/null 2>&1 && echo true || echo false)
VIFO=$(command -v vainfo 1>/dev/null 2>&1 && echo true || echo false)
INTE=$(ls /usr/bin/intel_gpu_* 1>/dev/null 2>&1 && echo true || echo false)
IGPU=$(lshw -C video | grep -qE 'i915' && echo true || echo false)
NGPU=$(lshw -C video | grep -qE 'nvidia' && echo true || echo false)
DIST=$(. /etc/os-release;echo $ID$VERSION_ID)

igpuhetzner() {
if [[ $HMOD == "false" ]]; then exit 0; fi
if [[ $ITEL == "false" ]]; then sed -i "s/blacklist i915/#blacklist i915/g" /etc/modprobe.d/blacklist-hetzner.conf; fi
if [[ $IMOL == "false" ]]; then sed -i "s/GRUB_CMDLINE_LINUX_DEFAUL/#GRUB_CMDLINE_LINUX_DEFAUL/g" /etc/modprobe.d/blacklist-hetzner.conf; fi
if [[ $IMOL == "true" && $ITEL == "true" ]]; then update-grub 1>/dev/null 2>&1; fi
if [[ $GCHK == "false" ]]; then groupadd -f video 1>/dev/null 2>&1; fi
if [[ $GVID == "false" ]]; then usermod -aG video $(whoami) 1>/dev/null 2>&1; fi
if [[ $VIFO == "false" ]]; then apt install vainfo -yqq; fi
if [[ $INTE == "false" && $IGPU == "true" ]]; then apt update -yqq && apt install intel-gpu-tools -yqq; fi
endcommand
if [[ $IMOL == "true" && $ITEL == "true" && $GVID == "true" && $DEVT == "true" ]]; then echo "Intel IGPU is working"; else echo "Intel IGPU is not working"; fi
}
nvidiagpu() {
if [[ $RCHK == "false" ]]; then
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
     apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$DIST/nvidia-docker.list | \
     tee /etc/apt/sources.list.d/nvidia-docker.list
fi
if [[ $CHKN != "true" ]]; then
   package_list="nvidia-container-toolkit nvidia-container-runtime"
   packageup="update upgrade dist-upgrade"
   for i in ${packageup}; do
       apt $i -yqq 1>/dev/null 2>&1
   done
   for i in ${package_list}; do
       apt install $i -yqq 1>/dev/null 2>&1
   done
fi
if [[ $DCHK == "false" ]]; then
sudo tee /etc/docker/daemon.json <<EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF
fi
if [[ $GVID == "false" ]]; then usermod -aG video $(whoami); fi
if [[ $DREA == "true" ]]; then pkill -SIGHUP dockerd; fi
endcommand
if [[ $DREA == "true" && $DCHK == "true" && $CHKN == "true" && $DEVT != "false" ]]; then echo "nvidia-container-runtime is working"; else echo "nvidia-container-runtime is not working"; fi
}
endcommand() {
if [[ $DEVT != "false" ]]; then
   chmod -R 750 /dev/dri
else
   echo ""
   printf "\033[0;31m You need to restart the server to get access to /dev/dri
after restarting execute the install again\033[0m\n"
   echo ""
   read -p "Type confirm to reboot: " input
   if [[ "$input" = "confirm" ]]; then reboot -n; else endcommand; fi
fi
}
while true; do
    if [[ $IGPU == "true" && $NGPU == "false" ]]; then igpuhetzner && break && exit; 
  elif [[ $IGPU == "true" && $NGPU == "true" ]]; then nvidiagpu && break && exit;
  elif [[ $IGPU == "false" && $NGPU == "true" ]]; then nvidiagpu && break && exit;
  else break && exit;fi
done
