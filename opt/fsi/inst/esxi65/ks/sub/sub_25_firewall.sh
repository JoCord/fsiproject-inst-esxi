#!/bin/sh
#
#   configure firewall
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
ver="1.02 - 23.2.2016"
retc=0
ls="  "
me=`basename $0`
ntpcfg="/etc/ntp.conf"

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"


infmsg "$ls ESXi - $me $ver"

### FIREWALL CONFIGURATION ###
 
# enable firewall
esxcli network firewall set --default-action false --enabled yes
 
# services to enable by default
FIREWALL_SERVICES="syslog sshClient ntpClient updateManager httpClient netdump"
for SERVICE in ${FIREWALL_SERVICES}
do
 esxcli network firewall ruleset set --ruleset-id ${SERVICE} --enabled yes
done


infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc

