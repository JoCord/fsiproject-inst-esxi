#!/bin/sh
#
#   sub_20_loc-store.sh - rename local storage
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
ver="1.05 - 18.9.2014"
retc=0
me=`basename $0`
ls="  "

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

locstore=loc_$hostname
found_store=$(esxcfg-scsidevs -m |  awk '{print $NF}')
if [ "$found_store" == "$locstore" ]; then
   infmsg "$ls  local storage already renamed"
else
   tracemsg "$ls  old local storage name: $found_store"
   infmsg "$ls  rename local storage to [$locstore]"
   vim-cmd hostsvc/datastore/rename "$found_store" "$locstore"
   retc=$?
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc