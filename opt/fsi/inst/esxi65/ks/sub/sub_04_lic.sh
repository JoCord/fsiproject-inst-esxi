#!/bin/sh
#
#   sub_05_lic.sh - set lic
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
ver="1.04 - 16.9.2014"
retc=0
ls="  "
me=`basename $0`
lic="none"
waitend=10
waittime=2
waitcount=0

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

infmsg "$ls  read ks.cfg for settings "

debmsg "$ls  read lic"
while read line; do
  licline=$(echo $line| cut -c -5)
  if [ "$licline" == "#lic:" ] ; then
     infmsg "$ls  found lic"
     lic=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
     debmsg "$ls   ==> license: [$lic]"
  fi
done < $ksfile

if [ "$lic" == "none" ]; then
   warnmsg "$ls   no lic found in ks.cfg"
else
   infmsg "$ls  found lic: $lic"

   echo -n $(date +%H:%M:%S)" INFO$ls   : Waiting ."
   while [ $waitcount -le $waitend ]; do
      echo -n "."
      sleep $waittime
      waitcount=$((waitcount+1))
   done
   echo " ok"

   debmsg "$ls  install lic now ..."
   OUTPUT=$(2>&1 vim-cmd vimsvc/license --set $lic )
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set lic - [$OUTPUT]"
   else
      debmsg "$ls  installed!"
      tracemsg "$ls  output: $OUTPUT"
   fi
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc