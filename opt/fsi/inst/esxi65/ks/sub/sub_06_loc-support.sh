#!/bin/sh
#
#   sub_06_loc-support.sh - enable local support
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
ver="1.07 - 2.10.2014"
me=`basename $0`
ls="  "

disable="none"

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
   disline=$(echo $line| cut -c -7)
   if [ "$disline" == "#local:" ] ; then
     disable=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
   fi
done < $ksfile

tracemsg "$ls    ==> disable found : [$disable]"
if [ "$disable" != "disable" ]; then
   infmsg "$ls  Enable Tech Support Mode (Local)"
   if [ $esximver -eq 4 ]; then
      tracemsg "$ls  ESXi 4 Mode"
      vim-cmd hostsvc/enable_local_tsm
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
      infmsg "$ls  Start Tech Support Mode (Local)"
      vim-cmd hostsvc/start_local_tsm
      retc=$?
   elif [ $esximver -eq 5 ]; then
      tracemsg "$ls  ESXi 5 Mode"
      vim-cmd hostsvc/enable_esx_shell
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
      infmsg "$ls  Start Tech Support Mode (Local)"
      vim-cmd hostsvc/start_esx_shell
      retc=$?
   elif [ $esximver -eq 6 ]; then
      tracemsg "$ls  ESXi 6 Mode"
      vim-cmd hostsvc/enable_esx_shell
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
      infmsg "$ls  Start Tech Support Mode (Local)"
      vim-cmd hostsvc/start_esx_shell
      retc=$?
   else
      errmsg "unsupported esxi version - do not know how to set tech mode"
      retc=99
   fi
   tracemsg "$ls  ==>rc=$retc"
else
   infmsg "$ls  Disable Tech Support Mode (Local)"
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc