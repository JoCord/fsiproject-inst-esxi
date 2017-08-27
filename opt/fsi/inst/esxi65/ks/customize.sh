#!/bin/sh
#
#   Customize-Script for Post-Installation ESX(i) Server
#
#   This program is free software; you can redistribute it and/or modify it under the 
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#   See the GNU General Public License for more details.
#  
#   You should have received a copy of the GNU General Public License along with this program; 
#   if not, see <http://www.gnu.org/licenses/>.
#
version="9.03.04 - 09.05.2017"
retc=0
me=`basename $0`
loglevel="trace"
export debug=$loglevel
kspath="none"
ksfile="none"
fsiweb="none"
kscfg="none"
kspathfile="none"
vitds="none"
esxiver="none"
esximver="none"

if [ -z "$vipath" ]; then
   if [ -f /store/fsi/viconf.sh ] ; then
       . /store/fsi/viconf.sh
   else
       echo "ERROR cannot set fsi conf variables"
       exit 99
   fi
fi
if [ "$esxiver" == "none" ]; then
   export esxiver=$(vmware -v | awk '{print $3}')
   echo export esxiver=$esxiver >>$viconf
fi
   
if [ "$esximver" == "none" ]; then
   case "$esxiver" in
      "4"*)
         export esximver=4
        ;;
      "5"*)
         export esximver=5
        ;;
      "6"*)
         export esximver=6
        ;;
      *)
         export esximver="unknown"
         echo "ERROR unsupported esxi version - abort" >>$vipath/viesxinst.log
         exit 99
        ;;
   esac
   echo export esximver=$esximver >>$viconf
fi

if [ "$vitds" == "none" ]; then
   export esxitree=$esxitree
   export vitds="nfs_fsi_"$esxitree
   echo export esxitree=$esxitree >>$viconf
   echo export vitds=$vitds >>$viconf
fi

if [ "$kspath" == "none" ]; then
   export kspath="/vmfs/volumes/nfs_fsi_"$esxitree
   echo export kspath=$kspath >>$viconf
fi

if [ "$ksfile" == "none" ]; then
   export ksfile="$vipath/ks.cfg"
   echo export ksfile=$ksfile >>$viconf
fi

if [ "$fsiweb" == "none" ]; then
   export fsiweb="http://$fsisrv/pxe/sys"
   echo export fsiweb=$fsiweb >>$viconf
fi

if [ "$kscfg" == "none" ]; then
   export kscfg="ks-"$esxitree".cfg"
   echo export kscfg=$kscfg >>$viconf
fi

if [ "$kspathfile" == "none" ]; then
   export kspathfile="/fsi/kspath"
   echo export kspathfile=$kspathfile >>$viconf
fi

if [ -f $kspath"/tools/fsifunc.sh" ] ; then
   . $kspath"/tools/fsifunc.sh"
else
    echo "ERROR cannot load vi functions" >>$vipath/viesxinst.log
    exit 99
fi



# Main program
infmsg "- - - - - - - - - - - - - - - - - - - - - - - - - - -"
infmsg "Start $me script - v$version" 
infmsg "  loglevel: $debug"
infmsg "  hostname: $hostname"
infmsg " detec mac ..."

if [ $esximver -eq 4 ]; then
   macp=`esxcfg-vmknic -l | grep -i "vmk0" | awk '{print $8}'`
elif [ $esximver -eq 5 ]; then
   macp=$(localcli network nic list | awk '/vmnic0/ {print $7}')
elif [ $esximver -eq 6 ]; then
   macp=$(localcli network nic list | awk '/vmnic0/ {print $8}')
else
   errmsg "unsupported esxi version [$esximver] - abort"
   exit 99
fi

echo export macp=$macp >>$viconf
infmsg "  mac: [$macp]"

mac=`echo $macp | awk '{gsub(/:/,"");print}'`
echo export mac=$mac >>$viconf
debmsg "  mac: [$mac]"

macs=`echo $macp | awk '{gsub(/:/,"-");print}'`
echo export macs=$macs >>$viconf
debmsg "  mac: [$macs]"

infmsg " get config file ..."
ksconfig="$fsiweb/$macs/$kscfg"
tracemsg "  ==> ks file remote: $ksconfig"
tracemsg "  ==> ks file local: $ksfile"
wget $ksconfig -O $ksfile
retc=$?
tracemsg "  ==> rc=$retc"
if [ $retc -ne 0 ]; then
   errmsg "cannot get ks file - abort"
fi

if [ $retc -eq 0 ]; then
   infmsg "$ls  Read $ksfile for loglevel"
   while read line; do
      logline=$(echo $line| cut -c -5)
      if [ "$logline" == "#log:" ] ; then
         loglevel=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' | awk '{print tolower($0)}')
      fi
   done < $ksfile
   export debug=$loglevel
   infmsg "$ls  loglevel: $debug"
fi

if [ $retc -eq 0 ]; then
   infmsg " Read $ksfile for install environment information"
   esxenv="none"                               

   while read line; do
      esxline=$(echo $line| cut -c -8)
      if [ "$esxline" == "#esxenv:" ] ; then
         esxenv=$(echo $line| cut -d " " -f 2 | awk '{$1=$1;print}' | awk '{print tolower($0)}')
      fi
   done < $ksfile

   if [ "$esxenv" != "none" ] ; then
      infmsg " Found fsi environment $esxenv "
   else
      warnmsg " unknown fsi environment !"
   fi
   export esxenv
   echo export esxenv=$esxenv >>$viconf
fi

if [ $retc -eq 0 ]; then
   infmsg " Copy tools to local esxi ..."
   OUTPUT=$(2>&1 cp -f $kspath/tools/* $vipath)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot copy tools [$OUTPUT] - rc=$retc"
   fi
fi

if [ $retc -eq 0 ]; then
   infmsg " Start Sub routines"
   for Subs in `ls $kspath/sub/sub_*.sh`; do
      if [ $retc -eq 0 ]; then
         infmsg " => call script $Subs"
         $Subs
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "subroutine $Subs rc=$retc"
            break
         fi
      fi      
   done
fi

tracemsg "$ls  [`cat $hostsvc_file`]"

infmsg "- - - - - - - - - - - - - - - - - - - - - - - - - - -"
infmsg "ESXi Installation ended rc=[$retc]"
if [ $retc -ne 0 ] ; then
   errmsg "Installation failed, please fix error"
else
   infmsg "Reboot ESXi Server to finish installation"
   reboot
fi

