#!/bin/sh
#
#   sub_54_vmnet.sh - configure additional vm networks
#   Copyright (C) 2012 js, virtuallyGhetto (William Lam)
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
#   Status: Develop
#
ver="1.00.07 - 18.9.2014"
retc=0
ls="  "
me=`basename $0`

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

new_func() {
   local FUNCNAME=""
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

restart_net() {
   local FUNCNAME="restart_net"
   local ls="       "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   infmsg "$ls  refresh network"
   vim-cmd hostsvc/net/refresh
   sleep 5

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_pgnicpol() {
   local FUNCNAME="set_pgnicpol"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vknics=$1
   local pgname=$2
   local vswitch=$3
   
   infmsg "$ls  set nic order policy now"
      
   tracemsg "$ls  port group nics to set: [$vknics]"
   local nicactive=""
   local nicstandby=""
   local nicnotuse=""
   local niconvs=""
   local vnic
   local vnicname
   local nic
   local nicuse
   local nicname
   local vsnr
   debmsg "$ls  read all active, standby nics on vswitch"
   # niconvs=`esxcfg-vswitch -l | grep -i "$vswitch" | awk '{$1=$1;print}' | /usr/bin/cut -d " " -f 6`
   
   while read line; do
      vsline=$(echo $line | /usr/bin/cut -c -5)
      if [ "$vsline" == "#vsw:" ] ; then
         vsnr=$(echo $line | /usr/bin/cut -d ":" -f 2 | awk '{$1=$1;print}' )
         if [ "$vsnr" == "" ]; then
            vsnr=0
         fi
         if [ "vSwitch$vsnr" == "$vswitch" ]; then
            debmsg "$ls  found my vSwitch config in ks.cfg"
            niconvs=$(echo $line | /usr/bin/cut -d ":" -f 3 | awk '{$1=$1;print}' )
         else
            tracemsg "$ls  wrong vSwitch line [$vsline]"
         fi
      fi         
   done < $ksfile   
   
   
   if [ "$niconvs" == "" ]; then
      warnmsg "$ls  no nics found on vswitch ?"
      niconvs="none"
   else
      tracemsg "$ls   vSwitch all nics: [$niconvs]"
      for vnic in $niconvs; do
         tracemsg "$ls    vSwitch nic work on: [$vnic]"
         foundnic="none"
         founduse="none"

         vnicuse=$(echo $vnic | /usr/bin/cut -c -1)
         if [ "$vnicuse" != "v" ]; then
            vnicname=$(echo $vnic | /usr/bin/cut -c2-)
         else
            vnicname=$vnic
            vnicuse="+"
         fi
         tracemsg "$ls     => vswitch nic config [$vnic]"
         tracemsg "$ls     => vswitch nic usage char: [$vnicuse]"
         tracemsg "$ls     => vswitch nic: [$vnicname]"
         
         for nic in $vknics; do
            tracemsg "$ls     portgroup nic in config [$nic]"

            nicuse=$(echo $nic | /usr/bin/cut -c -1)
            if [ "$nicuse" != "v" ]; then
               nicname=$(echo $nic | /usr/bin/cut -c2-)
            else
               nicname=$nic
               nicuse="+"
            fi
            
            tracemsg "$ls      => portgroup nic usage char: [$nicuse]"
            tracemsg "$ls      => portgroup nic: [$nicname]"

            if [ "$vnicname" == "$nicname" ]; then
               debmsg "$ls      found $nicname in portgroup config [$nicuse]"    
               if [ "$nicuse" == "+" ]; then
                  debmsg "$ls      ==> activ use nic  [$vnicname]"
               elif [ "$nicuse" == "-" ]; then
                  debmsg "$ls      ==> nic not used  [$vnicname] "
               elif [ "$nicuse" == "_" ]; then
                  debmsg "$ls      ==> nic standby use  [$vnicname]"
               else
                  errmsg "unknown flag in config - abort"
                  retc=77
                  break
               fi
               foundnic=$nicname
               founduse=$nicuse
            else
               tracemsg "$ls      not same nic [$vnicname]/[$nicname] - ignore"
            fi    
         done
         
         if [  "$foundnic" == "none" ]; then
            debmsg "$ls      cannot find $vnicname in portgroup config - set to vswitch default"
            foundnic=$vnicname
            founduse=$vnicuse
         else
            debmsg "$ls      find new nic config in portgroup config for $vnicname"
         fi
            
         if [ "$founduse" == "+" ]; then
            debmsg "$ls      ==> activ use nic  [$foundnic]"
            nicactive="$nicactive,$foundnic"
         elif [ "$founduse" == "-" ]; then
            debmsg "$ls      ==> nic not used  [$foundnic] "
            nicnotuse="$nicnotuse,$foundnic"
         elif [ "$founduse" == "_" ]; then
            debmsg "$ls      ==> nic standby use  [$foundnic]"
            nicstandby="$nicstandby,$foundnic"
         else
            errmsg "unknown flag in config - abort"
            retc=77
            break
         fi
         
         
      done
            
      debmsg "$ls  create command call for nic config on portgroup"
      tracemsg "$ls   config activ nics: [$nicactive]"
      tracemsg "$ls   config standby nics: [$nicstandby]"
      tracemsg "$ls   config unused nics: [$nicnotuse]"
      
      if [ "$nicactive" != "" ]; then
         tracemsg "$ls    found activ nics"
         tracemsg "$ls      => active nics: $nicactive"
         nicactive=$(echo $nicactive | /usr/bin/cut -c2-)
         tracemsg "$ls    active nics: $nicactive"
      else
         tracemsg "$ls  nic active empty ?"
      fi
      
      if [ "$nicstandby" != "" ]; then
         tracemsg "$ls    found standby nics"
         tracemsg "$ls      => standby nics: $nicstandby"
         nicstandby=$(echo $nicstandby | /usr/bin/cut -c2-)
         tracemsg "$ls      => standby nics: $nicstandby"
      else
         tracemsg "$ls    no standby nics found"
      fi
      
      if [ "$nicnotuse" != "" ]; then
         tracemsg "$ls    found not used nics"
         tracemsg "$ls      => not used nics: $nicnotuse"
         nicnotuse=$(echo $nicnotuse | /usr/bin/cut -c2-)
         tracemsg "$ls      => not used nics: $nicnotuse"
      else
         tracemsg "$ls    no not used nics found"
      fi
      
      infmsg "$ls  configure nic order..."
      
      if [ "$nicactive" == "" ]; then
         if [ "$nicstandby" == "" ]; then
            if [ "$nicnotuse" == "" ]; then
               infmsg "$ls   no change on nic policy - take vswitch default"
            else
               infmsg "$ls   only disable nics found: $nicnotuse"
               # alle nics vom vswitch einfangen und auf not use setzen, keine Ahnung ob das so geht -> call in vmware community
               cmd="vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=''  --nicorderpolicy-standby='' "
            fi
         else
            infmsg "$ls   only stand-by nics found: $nicstandby"
            # alle nics einfangen, die nicstandby rausnehmen und auf not use setzen
            # command mit nicorderpolicy-standby ohne active setzen
            cmd="vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-standby=$nicstandby "
         fi
      else
         if [ "$nicstandby" == "" ]; then
            infmsg "$ls   active nics found, but no standby nics"
            cmd="vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$nicactive "
         else
            infmsg "$ls   found standby and active nics"
            cmd="vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$nicactive  --nicorderpolicy-standby=$nicstandby "
         fi
         tracemsg "$ls   ====> cmd: $cmd $vswitch $pgname"
         OUTPUT=$(2>&1 $cmd $vswitch "$pgname")
         retc=$?
         if [ $retc -ne 0 ]; then
            errmsg "cannot set nic order policy - $OUTPUT"
         else
            infmsg "$ls  successful set policy"
         fi
      fi
   
      if [ $retc -eq 0 ]; then
         restart_net
         retc=$?
      fi
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_vlan() {
   local FUNCNAME="set_vlan"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vlannr=$1
   local pgname=$2
   local vswitch=$3
   
   local OUTPUT
   
   if [ "$vlannr" != "none" ]; then
      infmsg "$ls  set vlan $vlannr on pg $pgname"
      OUTPUT=$(2>&1 /usr/sbin/esxcfg-vswitch -v $vlannr -p "$pgname" $vswitch )           
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   => ok"
      else
         errmsg "cannot set vlan $vlannr on portgroup $pgname on $vswitch"
         errmsg "[$OUTPUT] - abort"
      fi
   fi

   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi
       
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}



set_newpgname() {
   local FUNCNAME=""
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local oldpgname=$1
   local newpgname=$2

   debmsg "$ls  rename portgroup [$oldpgname] in [$newpgname]"
   OUTPUT=$(2>&1 vim-cmd hostsvc/net/portgroup_set --portgroup-name="$newpgname" vSwitch0 "$oldpgname")
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot rename portgrop [$oldpgname]"
   else
      debmsg "$ls  ok - restart network now"
      restart_net
      retc=$?
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_pgload() {
   local FUNCNAME="set_pgload"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local load=$1
   local pg=$2
   local vs=$3

   debmsg "$ls  set pg [$pg] on vswitch [$vs] to [$load]"
#  vim-cmd hostsvc/net/portgroup_set  --nicteaming-policy=loadbalance_ip vSwitch1 "VMKernel s1 v223 f" 
   OUTPUT=$(2>&1 vim-cmd hostsvc/net/portgroup_set --nicteaming-policy=$load $vs "$pg" )
   retc=$?
   if [ $retc -ne 0 ]; then
      errmsg "cannot set load balance policy - [$OUTPUT]"
   else
      infmsg "$ls  successful set load balance"
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}


create_pg() {
   local FUNCNAME="create_pg"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   local pgexist
   local portgroup=$1
   local vswitch=$2
   
   tracemsg "$ls  pg: $portgroup"
   tracemsg "$ls  vswitch: $vswitch"

   pgexist=$(esxcfg-vswitch -C "$portgroup")
   tracemsg "$ls  exist code: $pgexist"
    
   if [ $pgexist -eq 1 ]; then
      infmsg "$ls  $portgroup already exist"
   else
      infmsg "$ls  create [$portgroup] on $vswitch"
      OUTPUT=$(2>&1 /usr/sbin/esxcfg-vswitch $vswitch --add-pg="$pgname" )
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   => ok"
      else
         errmsg "cannot add port group [$OUTPUT] - abort"
      fi
   fi
   
   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi
       
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}


do_vmn() {
   local FUNCNAME="do_vmn"
   local ls="   "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   debmsg "$ls  read vm network configs"
   
   while read line; do
      vsline=$(echo $line | /usr/bin/cut -c -5)

      #key: sw.nr: vlan: used nics: mtu: loadbalance : comment flag to portgroup
      #vmn: 0 : 470 : -vmnic1 : 3000 : loadbalance_srcid : i
      #vmn: 0 : 370 : _vmnic1 : : : test
      #vmn: 0 : 570 : +vmnic1 : : loadbalance_ip
      #vmn: 0 : 670

      local vsnr="none"
      local vlannr="none"
      local vkmtu="none"
      local vknics="none"
      local vkload="none"
      local vkcomment="none"

      if [ "$vsline" == "#vmn:" ] ; then
         vsnr=$(echo $line | /usr/bin/cut -d ":" -f 2 | awk '{$1=$1;print}' )
         vlannr=$(echo $line | /usr/bin/cut -d ":" -f 3 | awk '{$1=$1;print}' )
         vknics=$(echo $line | /usr/bin/cut -d ":" -f 4 | awk '{$1=$1;print}' )
         vkmtu=$(echo $line | /usr/bin/cut -d ":" -f 5 | awk '{$1=$1;print}' )
         vkload=$(echo $line | /usr/bin/cut -d ":" -f 6 | awk '{$1=$1;print}' )
         vkcomment=$(echo $line | /usr/bin/cut -d ":" -f 7 | awk '{$1=$1;print}' )

         if [ "$vsnr" == "" ]; then
            vsnr="0"
         fi
         if [ "$vlannr" == "" ]; then
            vlannr="0"
         fi
         if [ "$vkip" == "" ]; then
            vkip="none"
         fi
         if [ "$vknm" == "" ]; then
            vknm="255.255.255.0"
         fi
         if [ "$vkgate" == "" ]; then
            vkgate="none"
         fi
         if [ "$vkflags" == "" ]; then
            vkflags="none"
         fi
         if [ "$vkmtu" == "" ]; then
            vkmtu="none"
         fi
         if [ "$vknics" == "" ]; then
            vknics="none"
         fi
         if [ "$vkcomment" == "" ]; then
            vkcomment="none"
         fi
         if [ "$vkload" == "" ]; then
            vkload="none"
         fi
 
         infmsg "$ls ====> found portgroup vm network config"
         tracemsg "$ls  vswitch nr: $vsnr"
         tracemsg "$ls  vlan: $vlannr"
         tracemsg "$ls  vmkernel mtu size: $vkmtu"
         tracemsg "$ls  vmkernel nic policy: $vknics"
         tracemsg "$ls  vmkernel load balance: $vkload"
         tracemsg "$ls  vmkernel comment: $vkcomment"

         vmnetname="VMn"
         pgname="$vmnetname - s$vsnr v$vlannr"
         debmsg "$ls  port group name: $pgname"

         if [ "$vkcomment" != "none" ]; then
            pgname="$pgname $vkcomment"
            debmsg "$ls  port group name: $pgname"
         fi

         if [ $retc -eq 0 ]; then
            create_pg "$pgname" "vSwitch$vsnr"
            retc=$?
         fi

         if [ $retc -eq 0 ]; then
            tracemsg "$ls  vSwitch: vSwitch$vsnr"
            set_vlan "$vlannr" "$pgname" "vSwitch$vsnr"
            retc=$?
         fi

         if [ $retc -eq 0 ]; then
            if [ "$vknics" != "none" ]; then
               set_pgnicpol "$vknics" "$pgname" "vSwitch$vsnr"
            else
               debmsg "$ls  no nic policy change"
            fi
         fi

         if [ $retc -eq 0 ]; then
            if [ "$vkload" != "none" ]; then
               set_pgload "$vkload" "$pgname" "vSwitch$vsnr"
            else
               debmsg "$ls  no nic loadblance change"
            fi
         fi
      fi
   done < $ksfile


   debmsg "$ls end func: $FUNCNAME"
   return $retc
}


# main
infmsg "$ls  start configure vm networks"
do_vmn
retc=$?
if [ $retc -eq 0 ]; then
   infmsg "$ls  configure finish"
else
   errormsg "configure end with error: $retc"
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc