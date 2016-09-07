#!/usr/bin/env bash
########################################################################
# Script Name          : vmtools.sh
# Author               : Lal Pasha Shaik
# Creation Date        : 19-Jun-2016
# Description          : Install VMware Tools
########################################################################

# Trap on Error
set -e

## Logging
#####################################################################
logdir=${logdir:-/var/adm/install-logs}
[[ -d $logdir ]] || mkdir -p $logdir
logfile=$logdir/${0##*/}.$(date +%Y%m%d-%H%M%S).log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>${logfile} 2>&1

tempdir=$(mktemp -d /tmp/ucmtmp.XXXXXXXXXX)
cd ${tempdir}

#syslog
logger -s -- "[$$] $0 start: $(date)"
logger -s -- "[$$] script started in $(pwd)"
logger -s -- "[$$] logfile is in $logfile"

export PS4="+ [\t] "

## Functions
#####################################################################

function cleanup_before_exit() {
  logger -s -- "[$$] $0 end :  $(date)"
  echo "$0 end: $(date)" >&3
  if [[ "${err}" != "0" ]] ; then
    cat ${logfile} >&3
  fi
  cd /tmp && rm -rf ${tempdir}
}

## Main
#####################################################################
trap cleanup_before_exit EXIT
echo "$0 start: $(date)" >&3

# Try to detect vmware hardware
dmidecode -s system-product-name | grep -iq VMware
if [[ $? -ne 0 ]]; then
  error  "no VMware hardware detected... exiting..."
  exit 0
fi

# Remove open-vm-tools if found
if rpm -q --quiet open-vm-tools ; then 
 rpm -e open-vm-tools
fi

# Install net-tools
if ! rpm -q --quiet net-tools ; then
	yum -y install net-tools
fi 

# Vmware tools pkg
[[ -z ${vmvers} ]] && vmvers=10.0.0-2977863
pkg=VMwareTools-${vmvers}.tar.gz

# Get the Vmware tools tar.gz from DML
if curl --output /dev/null --silent --head --fail ${pkgurl}/${pkg} ; then
curl -k ${pkgurl}/${pkg} -o ${pkg}
else
echo "ERROR: Unable to download ${pkg} from ${pkgurl}"
  exit 1
fi

if [[ -f ${pkg} ]]; then
 tar xzf $pkg
else
  echo "ERROR: unable to extract. Pls check ${pkg}"
  exit 1
fi

# Install dependencies 
yum -y install gcc glibc-headers kernel-devel kernel-headers make perl

sleep 1
# compile/configure VMwareTools
cd vmware-tools-distrib
cat > answers << EOFans
yes
/usr/bin
/etc/rc.d
/etc/rc.d/init.d
/usr/sbin
/usr/lib/vmware-tools
yes
/usr/lib
/var/lib
/usr/share/doc/vmware-tools
yes
yes
no
no
yes
yes
yes
EOFans

# Run install perl script 
./vmware-install.pl < answers


systemctl status vmware-tools

if [[ "$(systemctl is-active vmware-tools)" == "active" ]] ; then
  echo "VMware Tools Installation successful" >&3
fi
#Set err
err=0