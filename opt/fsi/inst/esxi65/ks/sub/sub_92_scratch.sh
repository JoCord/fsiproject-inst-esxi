#!/bin/sh
#
#   sub_92_scratch   set scratch location
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
ver="1.02.04 - 2.10.2014"
retc=0
me=`basename $0`
ls="  "

scratch="none"

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
   ksline=$(echo $line| cut -c -9)
   if [ "$ksline" == "#scratch:" ] ; then
     scratch=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
   fi
done < $ksfile


tracemsg "$ls    ==> scratch loc : [$scratch]"
if [ "$scratch" == "none" ]; then
   infmsg "$ls  no scratch location found - ignore"
else
   infmsg "$ls  scratch location configure - find if dir exist"
   if [ -d $scratch ]; then
      infmsg "$ls  scratch dir already exist"
   else
      infmsg "$ls  create scratch subdir $scratch"
      OUTPUT=$(2>&1 mkdir "$scratch" )           
      retc=$?
      if [ $retc -eq 0 ]; then
        infmsg "$ls   => ok"
      else
        errmsg "cannot create path and subdir $scratch"
        errmsg "[$OUTPUT] - abort"
      fi
   fi
      
   if [ $retc -eq 0 ]; then
      infmsg "$ls  Configure scratch location ..."
      tracemsg "$ls  cmd: vim-cmd hostsvc/advopt/update ScratchConfig.ConfiguredScratchLocation string $scratch"
      cmd="vim-cmd hostsvc/advopt/update ScratchConfig.ConfiguredScratchLocation string $scratch"
      tracemsg "$ls   cmd: $cmd"
      OUTPUT=$(2>&1 $cmd)
      retc=$?
      tracemsg "$ls  ==> rc=$retc"
      tracemsg "$ls   out: [$OUTPUT]"
   fi

   if [ $retc -eq 0 ]; then
      if [ $esximver -eq 4 ]; then
         tracemsg "$ls  ESXi 4 Mode"
         infmsg "$ls  Set configure scratch to true"
         cmd="vim-cmd hostsvc/advopt/update ScratchConfig.ConfiguredSwapState bool true "
         tracemsg "$ls   cmd: $cmd"
         OUTPUT=$(2>&1 $cmd)
         retc=$?
         tracemsg "$ls  ==> rc=$retc"
         tracemsg "$ls   out: [$OUTPUT]"
      elif [ $esximver -eq 5 ]; then
         tracemsg "$ls  ESXi 5 Mode"
         infmsg "$ls no configured swap state"
      elif [ $esximver -eq 6 ]; then
         tracemsg "$ls  ESXi 6 Mode"
         infmsg "$ls no configured swap state"
      else
         errmsg "unsupported esxi version - do not know how to set tech mode"
         retc=99
      fi
   fi
fi

echo logall=1 >>/etc/syslog.conf 

tracemsg "$ls scratch config: [$(vim-cmd hostsvc/advopt/view ScratchConfig)]"


infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc