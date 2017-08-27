#!/bin/sh
#
#   sub_32_syslog.sh - set syslog
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
ver="1.01.05 - 6.3.2015"
retc=0
ls="  "
me=`basename $0`

if [ -f /store/fsi/viconf.sh ] ; then
    . /store/fsi/viconf.sh
else
    echo "ERROR cannot set vi conf variables"
    exit 99
fi
if [ -f /store/fsi/fsifunc.sh ] ; then
    . /store/fsi/fsifunc.sh
else
    echo "ERROR cannot load vi functions"
    exit 99
fi

infmsg "$ls ESXi - $me $ver"

if [ $esximver -eq 5 ] || [ $esximver -eq 6 ]; then
   tracemsg "$ls  ESXi 5/6 mode"
   syslogconfig=""

   infmsg "$ls  read ks.cfg for settings "
   
   debmsg "$ls   find syslog srv lines"
   while read line; do
      sysline=$(echo $line| cut -c -8)
      if [ "$sysline" == "#syssrv:" ]; then
         syssrv=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
         if [ -z $syssrv ]; then
            warnmsg "$ls    something wrong with $line"
         else
            infmsg "$ls   found syslog server: $syssrv"
            debmsg "$ls    search if port or protocol defined"
            sysport=$(echo $line| cut -d ":" -f 3 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )      
            if [ -z $sysport ]; then
               debmsg "$ls    no port configure - take default 514"
               sysport=514                                                                                                                         # default port
            else
               infmsg "$ls    syslog port config: $sysport"
            fi   
            sysprot=$(echo $line| cut -d ":" -f 4 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )       
            if [ -z $sysprot ]; then
               debmsg "$ls    no protocol configure - take default udp"
               sysprot="udp"
            else
               infmsg "$ls    syslog protocol config: $sysprot"
            fi   
            infmsg "$ll    add syslog to actual config line"
            syslogconfig="$syslogconfig,$sysprot://$syssrv:$sysport"
            
         fi
      fi
      if [ "$sysline" == "#syspar:" ]; then
         infmsg "$ls  found syslog parameter config line"
         syspar_rot=8
         syspar_size=1024
         
         tempid=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
         tracemsg "$ls   id: [$tempid]"
         
         temprot=$(echo $line| cut -d ":" -f 3 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
         tracemsg "$ls   rotate: [$temprot]"
         
         tempsize=$(echo $line| cut -d ":" -f 4 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
         tracemsg "$ls   size: [$tempsize]"
         
         if [ "$tempid" == "" ]; then
            warnmsg "$ls  no id found - ignore line [$line]"
         else
            syspar_id=$tempid
            if [ "$temprot" != "" ]; then
               syspar_rot=$temprot
            fi   
            if [ "$tempsize" != "" ]; then
               syspar_size=$tempsize
            fi   
   
            cmd="esxcli system syslog config logger set --id=$syspar_id --rotate=$syspar_rot --size=$syspar_size"
            tracemsg "$ls   cmd: $cmd"
            infmsg "$ls  set syslog parameter for $syspar_id"
            $cmd
            retc=$?
            if [ $retc -eq 0 ]; then
               infmsg "$ls  parameter set ok"
            else
               errmsg "cannot set parameter for syslog [$retc]- abort"
               break
            fi
         fi   
      fi
     
     
   done < $ksfile
   
   if [ $retc -eq 0 ]; then
      if [ -z $syslogconfig ]; then
         infmsg "$ls  no syslog server config found - ignore"
      else
         infmsg "$ls  syslog config found"   # ToDo: port / protokoll in firewall ?
         syslogconfig=${syslogconfig##,}
         infmsg "$ls   configure syslog now: $syslogconfig"
         echo "syslogconfig=$syslogconfig" >>/store/fsi/viconf.sh
         
         debmsg "$ls  esxcli system syslog config set --loghost=$syslogconfig"
         esxcli system syslog config set --loghost=$syslogconfig
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "cannot set syslog config [$syslogconfig] - abort"
         fi
         
         if [ $retc -eq 0 ]; then
            infmsg "$ls  ok - reload syslog service"
            esxcli system syslog reload
            retc=$?
         fi   
            
         if [ $retc -eq 0 ]; then
            infmsg "$ls  set firewall to allow syslog going out"
            esxcli network firewall ruleset set --ruleset-id=syslog --enabled=true
            retc=$?
         fi
         
         if [ $retc -eq 0 ]; then
            infmsg "$ls  ok - reload firewall service"
            esxcli network firewall refresh
            retc=$?
         fi
      fi      
   fi   
   
   if [ $retc -eq 0 ]; then      
      infmsg "$ls  restart syslog service"
      esxcli system syslog reload
      retc=$?
   fi
     
   if [ $retc -eq 0 ]; then   
      debmsg "$ls  get actual syslog configuration"
      OUT=$(esxcli system syslog config get)
      debmsg "$ls  syslog config [$OUT]"
   fi


elif [ $esximver -eq 4 ]; then
   tracemsg "$ls  ESXi 4 mode"
   infmsg "$ls  read ks.cfg for settings "
   
   syssrv="none"
   sysport=514                                                                                                                         # default port
   
   debmsg "$ls   read syssrv"
   while read line; do
     ntpline=$(echo $line| cut -c -8)
     if [ "$ntpline" == "#syssrv:" ] ; then
        syssrv=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     fi
   done < $ksfile
   debmsg "$ls   ==> server: [$syssrv]"
   
   debmsg "$ls   read ntp port"
   while read line; do
     ntpline=$(echo $line| cut -c -9)
     if [ "$ntpline" == "#sysport:" ] ; then
        sysport=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     fi
   done < $ksfile
   debmsg "$ls   ==> port: [$port]"
   debmsg "$ls  end ks.cfg reading"
   
   if [ ! "$syssrv" == "none" ]; then
      infmsg "$ls  found ntp server: [$syssrv]"
      infmsg "$ls  configure new ntp server now ..."
      vim-cmd hostsvc/advopt/update Syslog.Remote.Hostname string $syssrv
      retc=$?
      if [ $retc -ne 0 ]; then
         errmsg "cannot set ntp server to [$syssrv] - abort"
      else
         infmsg "$ls  ok"
         infmsg "$ls  set ntp port"
         vim-cmd hostsvc/advopt/update Syslog.Remote.Port int $sysport
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "cannot set ntp port to [$sysport] - abort"
         else
            infmsg "$ls  ok"
         fi
      fi
   else
      warnmsg "$ls  cannot find ntp server - ignore"
   fi      
       
   # vim-cmd hostsvc/advopt/update Syslog.Local.DatastorePath string "[datastoreName] /logfiles/hostName.log"

else
   errmsg "unsupported esxi version - do not know how to set tech mode"
   retc=99
fi




infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc