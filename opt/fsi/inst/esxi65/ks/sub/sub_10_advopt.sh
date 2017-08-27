#!/bin/sh
#
#   sub_10_advopt   set advanced options
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
ver="1.01 - 1.8.2014"
retc=0
me=`basename $0`
ls="  "

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

debmsg "$ls   read ks.cfg"
while read line; do
   advopt="none"
   advkey="none"
   advtyp="none"
   ksline=$(echo $line| cut -c -8)
   if [ "$ksline" == "#advopt:" ] ; then
      advkey=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
      advtyp=$(echo $line| cut -d ":" -f 3 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
      advopt=$(echo $line| cut -d ":" -f 4 | awk '{$1=$1;print}' )
      tracemsg "$ls    ==> advanced key: [$advkey]"
      tracemsg "$ls    ==> advanced type: [$advtyp]"
      tracemsg "$ls    ==> advanced option: [$advopt]"
      if [ "$advkey" == "none" ]; then
         warnmsg "$ls    no advanced key configure - ignore"
      else
         if [ "$advkey" == "none" ]; then
            warnmsg "$ls    no type for adv. key [$advkey] configure - ignore"
         else
            if [ "$advopt" == "none" ]; then
               warnmsg "$ls    no options for adv. key [$advkey] configure - ignore"
            else
               infmsg "$ls    set key [$advkey] with option [$advopt] and type [$advtyp]"
               tracemsg "$ls    cmd: vim-cmd hostsvc/advopt/update $advkey $advtyp $advopt" 
               vim-cmd hostsvc/advopt/update $advkey $advtyp "$advopt" 
               retc=$?
               tracemsg "$ls  ==> rc=$retc"   
               if  [ $retc -ne 0 ]; then
                  errmsg "cannot set advanced option - $OUTPUT"
               else
                  infmsg "$ls  successful set advanced option"
               fi
            fi
         fi   
      fi
   fi   
done < $ksfile


infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc