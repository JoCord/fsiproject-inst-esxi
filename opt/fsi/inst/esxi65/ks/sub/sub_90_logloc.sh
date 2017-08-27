#!/bin/sh
#
#   sub_90_logloc   set log location
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
#   Dev-Info: http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2003322
#
#   Option   Description
#   Syslog.global.logDir    
#   A location on a local or remote datastore and path where logs are saved to. Has the format [DatastoreName] DirectoryName/Filename, which maps 
#   to /vmfs/volumes/DatastoreName/DirectoryName/Filename. The [DatastoreName] is case sensitive and if the specified DirectoryName does not exist, 
#   it will be created. If the datastore path field is blank, the logs are only placed in their default location. If /scratch is defined, the default 
#   is []/scratch/log. For more information on scratch, see Creating a persistent scratch location for ESXi (1033696). For all other cases, the default is blank.
#   Syslog.global.logHost   
#   A remote server where logs are sent using the syslog protocol. If the logHost field is blank, no logs are forwarded. Include the protocol and 
#   port, similar to tcp://hostname:514 or udp://hostname:514
#   Syslog.global.logDirUnique    
#   A boolean option which controls whether a host-specific directory is created within the configured logDir. The directory name is the hostname 
#   of the ESXi host. A unique directory is useful if the same shared directory is used by multiple ESXi hosts. Defaults to false.
#   Syslog.global.defaultRotate   
#   The maximum number of log files to keep locally on the ESXi host in the configured logDir. Does not affect remote syslog server retention. Defaults to 8.
#   Syslog.global.defaultSize
#   The maximum size, in kilobytes, of each local log file before it is rotated. Does not affect remote syslog server retention. Defaults to 1024 KB. 
#   For more information on sizing, see Providing Sufficient Space for System Logging.
#
ver="1.03.02 - 10.2.2014"
retc=0
me=`basename $0`
ls="  "

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
   logloc="none"
   logrot=""
   logsize=""
   logcreate=""
   logcount=0
   
   debmsg "$ls   read ks.cfg"
   while read line; do
      # tracemsg "$ls   found line: [$line]"
      ksline=$(echo $line| cut -c -8)        
      if [ "$ksline" == "#logloc:" ] ; then
        tracemsg "$ls   found line: [$line]"
        logloc=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
        logrot=$(echo $line| cut -d ":" -f 3 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
        logsize=$(echo $line| cut -d ":" -f 4 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
        logcreate=$(echo $line| cut -d ":" -f 5 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
        if [ "$logcreate" == "true" ] || [ "$logcreate" == "false" ]; then
           infmsg "$ls    set log unique dir create = $logcreate"
        else
           warnmsg "$ls    unknown parameter for unique dir create $logcreate - set to true"
           logcreate="true"
        fi
      fi
   done < $ksfile
   
   tracemsg "$ls    ==> log loc : [$logloc]"
   if [ "$logloc" == "none" ]; then
      infmsg "$ls  no log location found - ignore"
   else
      infmsg "$ls  found log location ..."
      
      option="--logdir=$logloc"
      
      if ! [ -z $syslogconfig ]; then
         infmsg "$ls   found remote syslog config - add this too"
         option="$option --loghost=$syslogconfig"
      else
         debmsg "$ls   no remote syslog config found"
      fi
   
      if [ -z $logcreate ]; then
         infmsg "$ls   no log create unique dir - take default"
      else
         infmsg "$ls   add log unique: $logcreate"
         option="$option --logdir-unique=$logcreate"
      fi
      
      if [ -z $logrot ]; then
         infmsg "$ls   no log rotation found - take default"
      else
         infmsg "$ls   add log rotation: $logrot"
         option="$option --default-rotate=$logrot"
      fi
      
      if [ -z $logsize ]; then
         infmsg "$ls   no log size found - take default"
      else
         infmsg "$ls   add log size: $logsize"
         option="$option --default-size=$logsize"
      fi
      
      infmsg "$ll   config log location: $option"
      esxcli system syslog config set $option
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
      if [ $retc -ne 0 ]; then
         errmsg "cannot set log location config [$syslogconfig] - abort"
      else
         infmsg "$ls  ok - reload log location service"
         esxcli system syslog reload
      fi
   fi

elif [ $esximver -eq 4 ]; then
   logloc="none"
   tracemsg "$ls  ESXi 4 mode"
   debmsg "$ls   read ks.cfg"
   while read line; do
      ksline=$(echo $line| cut -c -8)
      if [ "$ksline" == "#logloc:" ] ; then
        logloc=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
      fi
   done < $ksfile
   
   
   tracemsg "$ls    ==> syslog loc : [$logloc]"
   if [ "$logloc" == "none" ]; then
      infmsg "$ls  no log location found - ignore"
   else
      infmsg "$ls  Enable log location ..."
      tracemsg "$ls cmd:  vim-cmd hostsvc/advopt/update Syslog.Local.DatastorePath string $logloc"
      vim-cmd hostsvc/advopt/update Syslog.Local.DatastorePath string "$logloc"
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
   fi
   
   tracemsg "$ls  syslog config: [$(vim-cmd hostsvc/advopt/view Syslog)]"
else
   errmsg "unsupported esxi version - do not know how to set log location"
   retc=99
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc