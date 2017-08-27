#!/bin/sh
#
#   sub_71_store-iscsi.sh - create nfs storage
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
ver="1.00.02 - 17.9.2014"
retc=0
ls="  "
me=`basename $0`
nfscfg="none"

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

debmsg "$ls   read nfs configs"
while read line; do
   iscsiline=$(echo $line| cut -c -5)
   storename="none"
   iscsiserver="none"
   iscsitarget="none"
   if [ "$iscsiline" == "#iscsi:" ] ; then
      infmsg "$ls    found iscsi line in config"
      
   # esxcli swiscsi nic add -n vmk1 -d vmhba33  
   # esxcli server ServerName nmp roundrobin setconfig d DeviceIdentifyer iops 10 type iops
   
#   esxcli swiscsi nic add n <VMkernel ID> -d <Virtual HBA ID>
#   As an example:
#   esxcli swiscsi nic add -n vmk0 -d vmhba33
#   esxcli swiscsi nic add -n vmk1 -d vmhba33

# esxcli swiscsi nic list -d vmhba33
   fi
done < $ksfile

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc