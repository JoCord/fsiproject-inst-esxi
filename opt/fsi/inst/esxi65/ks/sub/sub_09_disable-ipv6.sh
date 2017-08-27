#!/bin/sh
#
#   sub_09_disable-ipv6.sh
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
ver="1.05.02 - 2.10.2014"
retc=0
ls="  "
me=`basename $0`

disable="false"


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
   disline=$(echo $line| cut -c -6)
   if [ "$disline" == "#ipv6:" ] ; then
     disable=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
   fi
done < $ksfile

tracemsg "$ls    ==> ipv6 disable setting found : [$disable]"
if [ "$disable" == "false" ]; then
   infmsg "$ls  disable ip v6 "
   if [ $esximver -eq 4 ]; then
      tracemsg "$ls  ESXi 4 Mode"
      OUTPUT=$(2>&1 esxcfg-vmknic --enable-ipv6 false )
      retc=$?
   elif [ $esximver -eq 5 ]; then
      tracemsg "$ls  ESXi 5 Mode"
      OUTPUT=$(2>&1 esxcli network ip set --ipv6-enabled=false )
      retc=$?
   elif [ $esximver -eq 6 ]; then
      tracemsg "$ls  ESXi 6 Mode"
      OUTPUT=$(2>&1 esxcli network ip set --ipv6-enabled=false )
      retc=$?
   else
      errmsg "unsupported esxi version - do not know how to set tech mode"
      retc=99
   fi
else
   infmsg "$ls  enable ip v6"
   if [ $esximver -eq 4 ]; then
      tracemsg "$ls  ESXi 4 Mode"
      OUTPUT=$(2>&1 esxcfg-vmknic --enable-ipv6 true )
      retc=$?
   elif [ $esximver -eq 5 ]; then
      tracemsg "$ls  ESXi 5 Mode"
      OUTPUT=$(2>&1 esxcli network ip set --ipv6-enabled=true )
      retc=$?
   elif [ $esximver -eq 6 ]; then
      tracemsg "$ls  ESXi 6 Mode"
      OUTPUT=$(2>&1 esxcli network ip set --ipv6-enabled=true )
      retc=$?
   else
      errmsg "unsupported esxi version - do not know how to set tech mode"
      retc=99
   fi
fi

if [ $retc -ne 0 ]; then
   errmsg "cannot $disable ipv6 - [$OUTPUT]"
else
   debmsg "$ls  $disable ok"
   tracemsg "$ls  output: $OUTPUT"
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc