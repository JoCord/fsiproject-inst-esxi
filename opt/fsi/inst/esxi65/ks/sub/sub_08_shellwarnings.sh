#!/bin/sh
#
#   sub_08_shellwarnings.sh - disable shell warnings
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
retc=0
ver="1.02 - 16.9.2014"
me=`basename $0`
ls="  "

disable="disable"

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

debmsg "$ls   read ks.cfg"
while read line; do
   disline=$(echo $line| cut -c -11)
   if [ "$disline" == "#shellwarn:" ] ; then
     disable=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
   fi
done < $ksfile

tracemsg "$ls    ==> disable found : [$disable]"
if [ "$disable" == "disable" ]; then
   infmsg "$ls  Disable Shell Warnings"
   vim-cmd hostsvc/advopt/update UserVars.SuppressShellWarning long 1
   retc=$?
   tracemsg "$ls  ==> rc=$retc"
elif [ "$disable" == "enable" ]; then
   infmsg "$ls  Enable Shell Warnings"
   vim-cmd hostsvc/advopt/update UserVars.SuppressShellWarning long 0
   retc=$?
   tracemsg "$ls  ==> rc=$retc"
else
   warnmsg "$ls  Unknown set for Shell Warnings in config found [$disable] - ignore"
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc