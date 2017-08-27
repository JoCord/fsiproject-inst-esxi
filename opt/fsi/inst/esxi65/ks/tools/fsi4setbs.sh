#!/bin/sh
#
#   config block size for local storage
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
ver="1.05 - 21.3.2014"
retc=0
me=`basename $0`
ls="  "

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"
debug="trace"

infmsg "$ls ESXi - $me $ver"

locstore=loc_$hostname
found_store=$(esxcfg-scsidevs -m |  awk '{print $NF}')

if [ $retc -eq 0 ]; then
   blocksize="none"
   debmsg "$ls   read ks.cfg"
   while read line; do
      bsline=$(echo $line| cut -c -7)
      if [ "$bsline" == "#locbs:" ] ; then
        blocksize=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
      fi
   done < $ksfile
   
   tracemsg "$ls    ==> blocksize found : [$blocksize]"
   if [ "$blocksize" != "none" ]; then
      infmsg "$ls  Change local storage blocksize to $blocksize"
   
      debmsg "$ls  Detect disk partition name again"
      found_store=$(esxcfg-scsidevs -m |  awk '{print $NF}')
      tracemsg "$ls  store name: $found_store"
#      if [ "$found_store" == "$locstore" ]; then
         logpath=$(esxcfg-scsidevs -m |  awk '{print $2}')
         if [ "__$logpath" == "__" ]; then
            errmsg "cannot detect local storage path"
            retc=99
         else
            tracemsg "$ls   path: $logpath"
            debmsg "$ls  Start formating now"   
            cmd="/sbin/vmkfstools -C vmfs3 -b $blocksize -S $locstore $logpath"
            tracemsg "$ls   cmd: $cmd"
            OUTPUT=$(2>&1 $cmd)
            tracemsg "$ls   out: [$OUTPUT]"
            retc=$?
            if [ $retc -eq 0 ]; then
               infmsg "$ls  format local storage ok !"
               debmsg "$ls  Wait 5 seconds for sync partition ...."
               sleep 5
            else
               errmsg "$ls  error during formating local storage"
            fi
         fi
#      fi
   else
      infmsg "$ls  Do not change blocksize from local storage"
   fi
fi   

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc