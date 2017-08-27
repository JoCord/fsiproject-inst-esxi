#!/bin/sh
#
#   sub_22_ntp.sh - config ntp
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
ver="1.02 - 14.4.2015"
retc=0
ls="  "
me=`basename $0`
ntpcfg="/etc/ntp.conf"

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"


infmsg "$ls ESXi - $me $ver"

infmsg "$ls  write standard ntp.conf ..."

#restrict default kod nomodify notrap nopeer noquery
#restrict -6 default kod nomodify notrap nopeer noquery
#restrict 127.0.0.1
#server   127.127.1.0 # local clock
#fudge    127.127.1.0 stratum 10  
#driftfile /var/lib/ntp/drift

cat > $ntpcfg <<"EOF1"
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
driftfile /var/lib/ntp/drift

EOF1

infmsg "$ls  read ks.cfg for settings "
debmsg "$ls   search ntpsrv"

while read line; do
  ntpline=$(echo $line| cut -c -8)
  if [ "$ntpline" == "#ntpsrv:" ] ; then
     ntpsrv=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     infmsg "$ls   found server: $ntpsrv"
     infmsg "$ls   write server to ntp.conf ..."
     echo server $ntpsrv >>$ntpcfg
     existrc=$?
     if [ $existrc -eq 1 ]; then
         errmsg "cannot add ntp server [$ntpsrv] to ntp conf [$ntpcfg] - abort"
         retc=99
         break 
     fi
  fi
done < $ksfile

cat >> $ntpcfg <<"EOF1"

driftfile /var/lib/ntp/drift
EOF1

#Note: To review the delay of the ntpq offset at end of day, create a folder named /var/log/ntp with the command:
#
#    mkdir /var/log/ntp
#
#Append these 4 lines to the ntp.conf file:
#
#    statistics loopstats
#    statsdir /var/log/ntp/
#    filegen peerstats file peers type day link enable
#    filegen loopstats file loops type day link enable
#
#The logs are now created in the new ntp directory.

if [ $retc -eq 0 ]; then
   infmsg "$ls   configure ntpd start"
   cmd="/sbin/chkconfig ntpd on"
   tracemsg "$ls     => cmd: $cmd"
   OUTPUT=$(2>&1 $cmd)
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot configure ntp start - rc=$retc [$OUTPUT]"
   fi
fi

#sudo service ntp stop
#sudo ntpd -gq
#sudo service ntp start


infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc

