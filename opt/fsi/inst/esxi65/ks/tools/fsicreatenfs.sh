#!/bin/sh
#
#   create nfs storages
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
#   Status: Beta & Develop
#
ver="1.00beta"
retc=0
ls="  "
me=`basename $0`
nfscfg="none"

. /store/fsi/viconf.sh
. /store/fsi/fsifunc.sh

infmsg "$ls ESXi - $me $ver"

if [ "$nfscfg" == "none" ]; then
   errmsg "no nfs storage file configure - abort"
   exit 99
fi

if [ ! -e $nfscfg ]; then
   errmsg "no nfs storage file $nfscfg exist - abort"
else
   debmsg "$ls   read nfs configs"
   while read line; do
      nfsline=$(echo $line| cut -c -4)
      storename="none"
      nfsserver="none"
      nfsexport="none"
      if [ "$nfsline" == "nfs:" ] ; then
         storename=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
         nfsserver=$(echo $line| cut -d ":" -f 3 | awk '{$1=$1;print}' )
         nfsexport=$(echo $line| cut -d ":" -f 4 | awk '{$1=$1;print}' )
        
         tracemsg "$ls    ==> store: [$storename]"
         tracemsg "$ls    ==> server: [$nfsserver]"
         tracemsg "$ls    ==> export: [$nfsexport]"
   
         if [ "$storename" == "" ]; then
            warnmsg "$ls   empty storage name"
            storename="none"
         fi
         if [ "$nfsserver" == "" ]; then
            warnmsg "$ls   empty nfs server"
            nfsserver="none"
         fi
         if [ "$nfsexport" == "" ]; then
            warnmsg "$ls   empty nfsexport"
            nfsexport="none"
         fi
              
         if [ "$storename" != "none" ]; then
            storename="nfs_$storename"
            infmsg "$ls   found storage configure for $storename"
            if [ "$nfsserver" != "none" ]; then
               infmsg "$ls   found nfs server $nfsserver"
               if [ "$nfsexport" != "none" ]; then
                  infmsg "$ls   found nfs export $nfsexport"
                  
                  nfspath="/vmfs/volumes/$storename"
                  if [ -d $nfspath ]; then
                     warnmsg "$ls   $storename already exist - ignore"
                  else
                     infmsg "$ls   start configure now ..."
                     cmd="esxcfg-nas -a $storename -o $nfsserver -s $nfsexport"
                     tracemsg "$ls     cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        errmsg "cannot create $storename $OUTPUT - abort"
                        break
                     else
                        infmsg "$ls   storage created successfull"
                     fi
                  fi
               else
                  wanrmsg "   ==> no nfs export found - abort [$storename] config"
               fi
            else
               warnmsg "$ls   ==> no nfs server found - abort [$storename] config"
            fi             
         else
            warnmsg "$ls   no storage name found - ignore"
         fi     
      fi
   done < $nfscfg
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc