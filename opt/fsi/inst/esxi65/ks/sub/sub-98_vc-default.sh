#!/bin/sh
#
#   Join VC
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
ver="2.06.12 - 21.11.2016"
retc=0
me=`basename $0`
ls="    "

pythonver=$(2>&1 python --version)
pythver=${pythonver##*\ }
pythmain=${pythver%%\.*}

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
infmsg "$ls  Read $ksfile for vc information"

debug="trace"
vc="none"
vcusr="none"
vcpass="none"
dc="none"
husr="root"
hpass="none"

infmsg "$ls  search vc"
while read line; do
  jvc=$(echo $line| cut -c -4)
  if [ "$jvc" == "#vc:" ] ; then
     vc=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
  fi
done < $ksfile

infmsg "$ls  search dc"
while read line; do
  jvc=$(echo $line| cut -c -4)
  if [ "$jvc" == "#dc:" ] ; then
     dc=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
  fi
done < $ksfile

infmsg "$ls  search vc user"
while read line; do
  jvc=$(echo $line| cut -c -7)
  if [ "$jvc" == "#vcusr:" ] ; then
     vcusr=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
  fi
done < $ksfile

while read line; do
  jvc=$(echo $line| cut -c -8)
  if [ "$jvc" == "#vcpass:" ] ; then
     vcpass=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
  fi
done < $ksfile

while read line; do
  jvc=$(echo $line| cut -c -6)
  if [ "$jvc" == "#husr:" ] ; then
     husr=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
  fi
done < $ksfile

while read line; do
  jvc=$(echo $line| cut -c -7)
  if [ "$jvc" == "#hpass:" ] ; then
     hpass=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
  fi
done < $ksfile

infmsg "$ls  Test if all information ready"
if [ "$vusr" == "none" ] ; then retc=99 ; fi
if [ "$vpass" == "none" ] ; then retc=99 ; fi
if [ "$dc" == "none" ] ; then retc=99 ; fi
if [ "$vc" == "none" ] ; then retc=98 ; fi

if [ $retc -ne 0 ] ; then
   if [ $retc -eq 98 ]; then
      infmsg "$ls  no vc found - no join vc needed"
      retc=0
   else
      errmsg "cannot find all info in ks.cfg for joining vc"
   fi
else
   infmsg "$ls  find all infos"
   
   if [ $esximver -eq 5 ] || [ $esximver -eq 6 ]; then
      infmsg "$ls  first disable firewall"
      esxcli network firewall set --enabled false
      # esxcli network firewall ruleset set -e true -r httpClient
   fi
       
   debmsg "$ls    ==> vc = [$vc] "
   debmsg "$ls    ==> dc = [$dc] "
   debmsg "$ls    ==> vc user = [$vcusr] "
   debmsg "$ls    ==> host user = [$husr] "
   tracemsg "$ls    ==> vc pass = [$vcpass] "
   tracemsg "$ls    ==> usr pass = [$hpass] "
   

   debmsg "$ls   start joining now (pyth $pythmain) ..."
   if [ $esximver -eq 5 ] || [ $esximver -eq 6 ]; then
      tracemsg "$ls   cmd: /usr/bin/python $kspath/sub/sub-98_vc_"$pythmain".py --vc $vc --vusr $vcusr --vcpass $vcpass --dc $dc --husr $husr --hcpass ******"
      /usr/bin/python "$kspath/sub/sub-98_vc_"$pythmain".py" --vc "$vc" --vusr "$vcusr" --vcpass "$vcpass" --dc "$dc" --husr "$husr" --hcpass "$hpass"
      retc=$?
      infmsg "$ls  end joining - please control your vc $vc - rc = $retc"
   elif [ $esximver -eq 4 ]; then
      debmsg "$ls   during first installation - ignore user password"
      /usr/bin/python "$kspath/sub/sub-98_vc_"$pythmain".py" --vc "$vc" --vusr "$vcusr" --vcpass "$vcpass" --dc "$dc" --husr "$husr" --hcpass ""
      retc=$?
      infmsg "$ls  end joining - please control your vc $vc - rc = $retc"
   else
      errmsg "unsupported esxi version - don not know how to join vc"
      retc=99
   fi
    
   if [ $retc -eq 0 ]; then
     infmsg "$ls  Wait for complete joining ..."
     sleep 300
     vpxrun=0
     while [ $vpxrun -le 10 ]; do
         debmsg "$ls   test if vpx daemon running"
         if [ $esximver -eq 5 ] || [ $esximver -eq 6 ]; then
            OUTPUT=$(/etc/init.d/vpxa status)
            retc=$?
         elif [ $esximver -eq 4 ]; then
            OUTPUT=$(/etc/opt/init.d/vmware-vpxa status)
            retc=$?
         fi
         if [ $retc -eq 0 ]; then
            vpxrun=11
         else
            debmsg "$ls    not running - sleep 10 seconds an try again ...."
            tracemsg "$ls    [$OUTPUT]"
            sleep 10
            vpxrun=$((vpxrun+1))
         fi
     done
     if [ $retc -eq 0 ]; then
        infmsg "$ls  ok."    
     else 
        errmsg "cannot join virtual center - abort"
     fi
   else
     errmsg "cannot join vc rc=$retc"
   fi  
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc