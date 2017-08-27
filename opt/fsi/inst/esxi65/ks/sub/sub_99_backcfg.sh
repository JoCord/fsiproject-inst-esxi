#!/bin/sh
#
#   sub_99_backcfg.sh
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
ver="1.01.01 - 18.8.2014"
retc=0
ls="  "
me=`basename $0`

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls Start ESXi backup config - $me $ver"

debmsg "$ls  backup configuration"
# /sbin/auto-backup.sh
OUTPUT=$(2>&1 /sbin/auto-backup.sh )
retc=$?
if [ $retc -ne 0 ]; then
   errmsg "cannot backup configuration - [$OUTPUT]"
else
   debmsg "$ls  config backuped"
   tracemsg "$ls  output: $OUTPUT"
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc