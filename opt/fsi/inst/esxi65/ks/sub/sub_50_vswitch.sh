#!/bin/sh
#
#   sub_50_vswitch.sh - configure vswitches
#   Copyright (C) 2012 js, virtuallyGhetto (William Lam), VMWare community
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
ver="1.06 - 14.5.2014"
retc=0
ls="  "
me=`basename $0`

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

restart_net() {
   local FUNCNAME="restart_net"
   local ls="       "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   infmsg "$ls  refresh network"
   vim-cmd hostsvc/net/refresh
   sleep 3

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_vsnicpol() {
   local FUNCNAME="set_vsnicpol"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vsnics=$1
   local vswitch=$2
   
   infmsg "$ls  set nic order policy now"
      
   local nicactive=""
   local nicstandby=""
   local nicnotuse=""
         
   for nic in $vsnics; do 
      nicuse=$(echo $nic| /usr/bin/cut -c -1)
      debmsg "$ls nic: $nic"
      if [ "$nicuse" == "+" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls       ==> default use nic"
         nicactive="$nicactive,$nicname"
      elif [ "$nicuse" == "-" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls       ==> nic not used, do not add it to change string "
         nicnotuse="$nicnotuse,$nicname"
      elif [ "$nicuse" == "_" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls       ==> nic standby use"
         nicstandby="$nicstandby,$nicname"
      elif [ "$nicuse" == "v" ]; then
         nicname=$nic
         debmsg "$ls       ==> nic default use"
         nicactive="$nicactive,$nicname"
      else
         errmsg "unknown flag in config - abort"
         retc=77
         break   
      fi
   done  # for nic ...
         
   if [ "$nicactive" != "" ]; then
      tracemsg "$ls  found activ nics"
      tracemsg "$ls      => active nics: $nicactive"
      nicactive=$(echo $nicactive | /usr/bin/cut -c2-)
      tracemsg "$ls      => active nics: $nicactive"
   else
      tracemsg "$ls  nic active empty ?"
   fi
   
   if [ "$nicstandby" != "" ]; then
      tracemsg "$ls  found standby nics"
      tracemsg "$ls      => standby nics: $nicstandby"
      nicstandby=$(echo $nicstandby | /usr/bin/cut -c2-)
      tracemsg "$ls      => standby nics: $nicstandby"
   else
      tracemsg "$ls      => no standby nics found"
   fi
   
   if [ "$nicnotuse" != "" ]; then
      tracemsg "$ls  found not used nics"
      tracemsg "$ls      => not used nics: $nicnotuse"
      nicnotuse=$(echo $nicnotuse | /usr/bin/cut -c2-)
      tracemsg "$ls      => not used nics: $nicnotuse"
   else
      tracemsg "$ls      => no not used nics found"
   fi
   
   infmsg "$ls  configure nic order..."
   
   if [ "$nicstandby" == "" ]; then
      debmsg "$ls  no standby nics found"
      cmd="vim-cmd hostsvc/net/vswitch_setpolicy --nicorderpolicy-active=$nicactive "
   else
      debmsg "$ls  found standby nics"
      cmd="vim-cmd hostsvc/net/vswitch_setpolicy --nicorderpolicy-active=$nicactive  --nicorderpolicy-standby=$nicstandby "
   fi
   
   tracemsg "$ls   cmd: $cmd $vswitch"
   OUTPUT=$(2>&1 $cmd $vswitch )
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set nic order policy - $OUTPUT"
   else
      infmsg "$ls  successful set policy"
   fi

   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}


set_vsnicadd () {
   local FUNCNAME="set_vsnicadd"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vsnics=$1
   local vswitch=$2

   local nic
   local nicname
   local nicuse
   local cmd
   local OUTPUT
      
   debmsg "$ls  read nics from config"   
   for nic in $vsnics; do 
      tracemsg "$ls   nic: $nic"
      nicuse=$(echo $nic| /usr/bin/cut -c -1)
      tracemsg "$ls   nic usage: [$nicuse]"
      if [ "$nicuse" == "+" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls ==> default use nic"
      elif [ "$nicuse" == "-" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls ==> nic not used"
      elif [ "$nicuse" == "_" ]; then
         nicname=$(echo $nic | /usr/bin/cut -c2-)
         debmsg "$ls ==> nic standby use"
      elif [ "$nicuse" == "v" ]; then
         nicname=$nic
         debmsg "$ls ==> nic default use"
      else
         errmsg "unknown nic [$nic] config"
         retc=77
      fi
   
      if [ $retc -eq 0 ]; then
         infmsg "$ls  add [$nicname] to $vswitch"
         cmd="esxcfg-vswitch -L $nicname $vswitch"
         tracemsg "$ls    ====> cmd: [$cmd]"
         OUTPUT=$(2>&1 $cmd)
         retc_add=$?
         if [ $retc_add -ne 0 ]; then
            nicexist=$( echo $OUTPUT | grep -i "Error: Uplink already exists")
            if [ "$nicexist" == "" ]; then
               errmsg "===> cannot add $nicname to $vswitch"
               errmsg "Output: $OUTPUT"
               retc=88
            else
               warnmsg "$ls   ===> $nicname already linked to $vswitch"
            fi
         fi
      fi
   done
   
   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_vsteam ( ) {
   local FUNCNAME="set_vsteam"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vsteaming=$1
   local vswitch=$2

   infmsg "$ls  set nic teaming to $vsteaming"
   vim-cmd hostsvc/net/vswitch_setpolicy --nicteaming-policy="$vsteaming" $vswitch
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set nic teaming $vsteaming to $vswitch"
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

         



debmsg "$ls  read nfs configs"

debmsg "$ls  read vswitch configs"
ls="   "
while read line; do
   vsline=$(echo $line| /usr/bin/cut -c -5)
   vsnr="none"
   vsnics="none"
   vsteaming="none"
   vsmtu="none"
   if [ "$vsline" == "#vsw:" ] ; then
      vsnr=$(echo $line| /usr/bin/cut -d ":" -f 2 | awk '{$1=$1;print}' )
      vsnics=$(echo $line| /usr/bin/cut -d ":" -f 3 | awk '{$1=$1;print}' )
      vsteaming=$(echo $line| /usr/bin/cut -d ":" -f 4 | awk '{$1=$1;print}' )
      vsmtu=$(echo $line| /usr/bin/cut -d ":" -f 5 | awk '{$1=$1;print}' )

      if [ "$vsnr" == "" ]; then
         vsnr=0
      fi
      if [ "$vsteaming" == "" ]; then
         vsteaming="none"
      fi
      if [ "$vsmtu" == "" ]; then
         vsmtu="none"
      fi
      if [ "$vsnics" == "" ]; then
         vsnics="none"
      fi
      
      infmsg "$ls ====> found vSwitch$vsnr config"
      debmsg "$ls  vswitch nr: $vsnr"
      debmsg "$ls  vswitch nics: $vsnics"
      debmsg "$ls  vs nic teaming: $vsteaming"

      debmsg "$ls  test if vSwitch$vsnr exist"
      exist=$(esxcfg-vswitch -c vSwitch$vsnr)
      if [ $exist -eq 1 ]; then
         infmsg "$ls  vSwitch$vsnr already exist"
      else
         infmsg "$ls create vSwitch$vsnr"
         esxcfg-vswitch -a vSwitch$vsnr
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "cannot create vSwitch$vsnr - abort"
            break
         else
            infmsg "$ls  ok"
         fi
      fi
   
      if [ $retc -eq 0 ]; then
         if [ "$vsnics" != "none" ]; then
            set_vsnicadd "$vsnics" "vSwitch$vsnr"
            retc=$?
         else
            debmsg "$ls  no nics to add configure"
         fi
      fi 

      if [ $retc -eq 0 ]; then
         if [ "$vsteaming" != "none" ]; then
            set_vsteam "$vsteaming" "vSwitch$vsnr"
            retc=$?         
         else
            infmsg "$ls  no teaming configure - leave default"
         fi
      fi
      
      if [ $retc -eq 0 ]; then
         restart_net
         retc=$?
      fi
        
      if [ $retc -eq 0 ]; then
         if [ "$vsmtu" != "none" ]; then
            infmsg "$ls  found mtu size: $vsmtu"
            esxcfg-vswitch -m $vsmtu vSwitch$vsnr
            if [ $retc -ne 0 ]; then
               errmsg "cannot set mtu size $vsmtu to vSwitch$vsnr"
            fi
         else
            infmsg "$ls  no mtu size configure - leave default"
         fi
      fi
      
      if [ $retc -eq 0 ]; then
         if [ "$vsnics" != "none" ]; then
            set_vsnicpol "$vsnics" "vSwitch$vsnr"
            retc=$?
         else
            debmsg "$ls  no nics policy to configure"
         fi
      fi   
         
   fi
done < $ksfile
ls="  "

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc