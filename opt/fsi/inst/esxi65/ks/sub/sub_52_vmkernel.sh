#!/bin/sh
#
#   sub_52_vmkernel.sh - configure additional vmkernel interfaces
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
#
ver="1.00.17 - 18.9.2014"
retc=0
ls="  "
me=`basename $0`

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"
vmotion=0      # vmotion not set


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

set_newpgname() {
   local FUNCNAME="set_newpgname"
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
   tracemsg "$ls  exist code: [$pgexist]"
    
   if [ "$pgexist" == "1" ]; then   # do not use as integer, use char
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

      if [ $retc -eq 0 ]; then
         restart_net
         retc=$?
      fi
   else
      warnmsg "$ls  no vlan given ?"
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_ip() {
   local FUNCNAME="set_ip"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local vkip=$1
   local vknm=$2
   local pgname=$3
   
   local OUTPUT

   if [ "$vkip" != "none" ]; then
      infmsg "$ls  set ip $vkip to port group"
      OUTPUT=$(2>&1 /usr/sbin/esxcfg-vmknic -a -i "$vkip" -n "$vknm" "$pgname"  )           
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   => ok"
      else
         errmsg "cannot set ip $vkip on portgroup $pgname"
         errmsg "[$OUTPUT] - abort"
      fi
      if [ $retc -eq 0 ]; then
         restart_net
         retc=$?
      fi
   else
      warnmsg "$ls  no ip given ?"
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_vmotion() {
   local FUNCNAME="set_vmotion"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local pgname=$1
   
   local vmkint
   local OUTPUT

   debmsg "$ls  get vmkernel interface name"    
   tracemsg "$ls  port group name: $pgname"       
   vmkint=$(2>&1 /usr/sbin/esxcfg-vmknic -l | grep "IPv4" | grep -i "$pgname" | /usr/bin/cut -d " " -f 1 | awk '{$1=$1;print}')
   retc=$?
   
   if [ $retc -eq 0 ]; then
      debmsg "$ls  vmk interface: [$vmkint]"
      tracemsg "$ls  cmd: vim-cmd hostsvc/vmotion/vnic_set $vmkint"
      OUTPUT=$(2>&1 vim-cmd hostsvc/vmotion/vnic_set $vmkint)
      retc=$?
      if [ $retc -eq 0 ]; then
         infmsg "$ls   vmk interface $vmkint vmotion ok"
      else
         errmsg "cannot set vmotion on vmk interface rc=$retc [$OUTPUT]"
      fi
   else
      errmsg "cannot get vmk interface [$vmkint]"
   fi

   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_ft() {
   local FUNCNAME="set_ft"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   warnmsg "$ls  not implemented - add fault tolerance"
   ##ToDo: add fault tolerance flag for network
   
   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_mm() {
   local FUNCNAME="set_mm"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0
   local pgname=$1
   
   local vmk
   local hostsvc_file="/etc/vmware/hostd/hostsvc.xml"
   
   infmsg "$ls  Enable Management Traffic on $pgname"

   debmsg "$ls  get vmkernel interface name"           
   vmk=$(2>&1 /usr/sbin/esxcfg-vmknic -l | grep "IPv4" | grep -i "$pgname" | /usr/bin/cut -d " " -f 1 | awk '{$1=$1;print}')
   retc=$?
   
   if [ $retc -eq 0 ]; then
      debmsg "$ls  vmkernel interface: [$vmk]"
      debmsg "$ls  vmkernel already set for management traffic ?"
      tracemsg "$ls  [`cat $hostsvc_file`]"
      grep ${vmk} ${hostsvc_file} > /dev/null 2>&1
      vmkexist=$?
      if [ $vmkexist -eq 0 ]; then
         warnmsg "$ls  vmkernel interface: $vmk is already enabled with managment traffic"
      else
         infmsg "$ls  set vmkernel interface $vmk for management traffic"
         sectok=$(sed -n '/mangementVnics/,/mangementVnics/p' $hostsvc_file)
         if [ "$sectok" == "" ]; then
            debmsg "$ls  no management network define ?"
            ##ToDo: geht nicht !!!!
            OUTPUT=$(2>&1 sed -i "/id=\"<ConfigRoot>\"/a  <managementVnics> \n </managementVnics>" $hostsvc_file)
            retc=$?
            if [ $retc -eq 0 ]; then
               debmsg "$ls  ok"
               tracemsg "$ls  [`cat $hostsvc_file`]"
            else
               errmsg "failed to write to $hostsvc_file"
            fi
         fi
         ##ToDo: geht nicht
         current_nic_id=$(sed -n '/mangementVnics/,/mangementVnics/p' $hostsvc_file | grep vmk | sed 's/.*"\(.*\)"[^"]*$/\1/' | sort -n | tail -1)
         tracemsg "$ls  current nic: $current_nic_id"
         current_nic_plus_one_id=$((current_nic_id+1))
         tracemsg "$ls  current nic(plus): $current_nic_plus_one_id"
         next_nic_id=$(printf "%04d" $current_nic_plus_one_id)
         tracemsg "$ls  next nic: $next_nic_id"
         debmsg "$ls  set vmk interfaces to config file"
         OUTPUT=$(2>&1 sed -i "/id=\"$current_nic_id\"/a  <nic id=\"$next_nic_id\">$vmk</nic>" $hostsvc_file)
         retc=$?
         if [ $retc -eq 0 ]; then
            debmsg "$ls  vmk in configfile"
# ToDo:
            tracemsg "$ls  [`cat $hostsvc_file`]"
            sleep 5
            infmsg "$ls  restart hostd now ..."
#            OUTPUT=$(2>&1 /etc/init.d/hostd restart )
#            retc=$?
#            if [ $retc -eq 0]; then
#               debmsg "$ls  Wait 5 seconds for restarting ...."
#               sleep 5
#               debmsg "$ls  ok"
#            else
#               errmsg "cannot restart hostd - [$OUTPUT]"
#            fi
         else
            errmsg "cannot set $vmk as management network [$OUTPUT] - abort"
         fi
      fi
   else
      errmsg "cannot get vmkernel interface [$vmk] - abort"
   fi   
   
   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi

   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

set_gw() {
   local FUNCNAME="set_gw"
   local ls="     "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0


   warnmsg "$ls  function not implemented"    
      
   ##ToDo: add gateway function
   #  esxcfg-route -a 192.168.100.0 255.255.255.0 192.168.0.1
   #  esxcfg-route -a default 192.168.0.1


   if [ $retc -eq 0 ]; then
      restart_net
      retc=$?
   fi

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


do_vmm() {
   local FUNCNAME="do_vmm"
   local ls="    "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0

   debmsg "$ls  read management network config first"
   
   debmsg "$ls  set vars to default"
   vsnr=0
   vlannr="none"
   vkgate="none"
   vkflags="none"
   vkmtu="none"
   vknics="none"
   vkload="none"
   vkcomment="none"
   
   while read line; do
      vsline=$(echo $line | /usr/bin/cut -c -5)
      
      #key: vlan: flags: default gate: mtu  : nics              :load: comment
      #vmm: 0   : m f  : 10.10.10.99 : 3000 : +vmknic0 _vmknic1 :     : nativ
      #vmm::m
      
      if [ "$vsline" == "#vmm:" ] ; then
         vlannr=$(echo $line | /usr/bin/cut -d ":" -f 2 | awk '{$1=$1;print}' )
         vkflags=$(echo $line | /usr/bin/cut -d ":" -f 3 | awk '{$1=$1;print}' )
         vkgate=$(echo $line | /usr/bin/cut -d ":" -f 4 | awk '{$1=$1;print}' )
         vkmtu=$(echo $line | /usr/bin/cut -d ":" -f 8 | awk '{$1=$1;print}' )
         vknics=$(echo $line | /usr/bin/cut -d ":" -f 9 | awk '{$1=$1;print}' )
         vkload=$(echo $line | /usr/bin/cut -d ":" -f 10 | awk '{$1=$1;print}' )
         vkcomment=$(echo $line | /usr/bin/cut -d ":" -f 11 | awk '{$1=$1;print}' )
   
         if [ "$vlannr" == "" ]; then
            debmsg "$ls   set default vlan for mm to 0"
            vlannr=0
         else
            debmsg "$ls   vlan: $vlannr"
         fi
         if [ "$vkflags" == "" ]; then
            debmsg "$ls   no flags configure for mm"
            vkflags="none"
         else
            debmsg "$ls   flags: $vkflags"
         fi
         if [ "$vkgate" == "" ]; then
            debmsg "$ls   no new default gateway configure"
            vkgate="none"
         else
            debmsg "$ls   default gateway: $vkgate"
         fi
         if [ "$vkmtu" == "" ]; then
            debmsg "$ls  no mm mtu configure"
            vkmtu="none"
         else
            debmsg "$ls   mm mtu size: $vkmtu"
         fi
         if [ "$vknics" == "" ]; then
            debmsg "$ls   no nic change or configure for mm"
            vknics="none"
         else
            debmsg "$ls   nic config: $vknics"
         fi
         if [ "$vkcomment" == "" ]; then
            debmsg "$ls   no mm comment configure"
            vkcomment="none"
         else
            debmsg "$ls   mm comment: $vkcomment"
         fi
         if [ "$vkload" == "" ]; then
            vkload="none"
         fi
         
         infmsg "$ls  only one vmm interface allowed - ignore other"
         break
      fi

   done < $ksfile

   local vmkname="VMk"
   pgname="$vmkname - s0 v0 t"

   if [ $retc -eq 0 ]; then
      if [ "$vkflags" != "none" ]; then
         for flag in $vkflags; do 
            setflag=$(echo $flag | /usr/bin/cut -c -1)
            if [ "$setflag" == "f" ]; then
               infmsg "$ls  => set fault tolerance"
               setfault=1
               pgname="$pgname f"
            elif [ "$setflag" == "m" ]; then
               if [ $vmotion -eq 0 ]; then
                  infmsg "$ls  => set vmotion"
                  setvmotion=1
                  pgname="$pgname m"
                  vmotion=1
               else
                  errmsg "vMotion already set - please control you config - abort"
                  retc=99
                  break
               fi
#            elif [ "$setflag" == "t" ]; then
#               infmsg "$ls  => set management traffic"
#               setmm="1"
#               pgname="$pgname t"
            else
               errmsg "unknown flag [$setflag] - ignore"
            fi
         done # for flag ...
      else
         debmsg "$ls  no flags given and add to pg name"
      fi
   fi 

   if [ "$vkcomment" != "none" ]; then
      pgname="$pgname $vkcomment"
      debmsg "$ls  port group name: $pgname"
   fi
   
             
   debmsg "$ls  rename mgmt network"
   
   if [ $retc -eq 0 ]; then
      set_newpgname "Management Network" "$pgname"
      retc=$?
   fi
      
#   if [ $retc -eq 0 ]; then
#      if [ "$setmm" == "1" ]; then
#         set_mm "$pgname"
#         retc=$?
#      else
#         debmsg "$ls  no management network traffic flag"
#      fi
#   fi

   if [ $retc -eq 0 ]; then
      if [ $setvmotion -eq 1 ]; then
         set_vmotion "$pgname"
         retc=$?
      else
         debmsg "$ls  no vmotion flag"
      fi   
   fi
   
   if [ $retc -eq 0 ]; then
      if [ $setfault -eq 1 ]; then
         set_ft "$pgname"
         retc=$?
      else
         debmsg "$ls  no fault tolerance flag"
      fi
   fi
   
   debmsg "$ls end func: $FUNCNAME"
   return $retc
}

do_vmk() {
   local FUNCNAME="do_vmk"
   local ls="    "
   debmsg "$ls start func: $FUNCNAME"
   local retc=0


   debmsg "$ls  read vmkernel configs"
   
   while read line; do
      vsline=$(echo $line | /usr/bin/cut -c -5)
      
      #key: sw.nr: vlan: ip:             netmask:        gateway:      flags: mtu:   used nics:                loadbalance       : comment flag to vswitch 
      #vmk: 0    : 23  : 10.10.11.173  : 255.255.255.0 : 10.10.11.99 :      : 3000 : -vmnic1 vmnic0          :                   : i  
      #vmk: 0    : 25  : 10.10.111.173 : 255.255.255.0 : 10.10.11.99 : t    : 3000 : -vmnic1                 : loadbalance_srcid : i  
      #vmk: 0    : 10  : 10.10.12.173  : 255.255.255.0 :             : t    : 9000 : _vmnic1                 :                   : i n 
      #vmk: 1    : 220 : 10.10.13.173  : 255.255.255.0 : 10.10.13.99 :      :      : _vmnic3 -vmnic4
      #vmk: 1    : 223 : 10.10.14.173  : 255.255.255.0 : 10.10.14.99 : f    :      : +vmnic2 _vmnic3 -vmnic4 : :
      
      vsnr="none"
      vlannr="none"
      vkip="none"
      vknm="none"
      vkgate="none"
      vkflags="none"
      setvmotion="none"
      setfault="none"
      setmm="none"
      vkmtu="none"
      vknics="none"
      vkload="none"
      vkcomment="none"
      
      if [ "$vsline" == "#vmk:" ] ; then
         vsnr=$(echo $line | /usr/bin/cut -d ":" -f 2 | awk '{$1=$1;print}' )
         vlannr=$(echo $line | /usr/bin/cut -d ":" -f 3 | awk '{$1=$1;print}' )
         vkip=$(echo $line | /usr/bin/cut -d ":" -f 4 | awk '{$1=$1;print}' )
         vknm=$(echo $line | /usr/bin/cut -d ":" -f 5 | awk '{$1=$1;print}' )
         vkgate=$(echo $line | /usr/bin/cut -d ":" -f 6 | awk '{$1=$1;print}' )
         vkflags=$(echo $line | /usr/bin/cut -d ":" -f 7 | awk '{$1=$1;print}' )
         vkmtu=$(echo $line | /usr/bin/cut -d ":" -f 8 | awk '{$1=$1;print}' )
         vknics=$(echo $line | /usr/bin/cut -d ":" -f 9 | awk '{$1=$1;print}' )
         vkload=$(echo $line | /usr/bin/cut -d ":" -f 10 | awk '{$1=$1;print}' )
         vkcomment=$(echo $line | /usr/bin/cut -d ":" -f 11 | awk '{$1=$1;print}' )
   
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
         
   
         infmsg "$ls ====> found portgroup vmkernel config"
         tracemsg "$ls  vswitch nr: $vsnr"
         tracemsg "$ls  vlan: $vlannr"
         tracemsg "$ls  vmkernel ip: $vkip"
         tracemsg "$ls  vmkernel netmask: $vknm"
         tracemsg "$ls  vmkernel gateway: $vkgate"
         tracemsg "$ls  vmkernel flags: $vkflags"
         tracemsg "$ls  vmkernel mtu size: $vkmtu"
         tracemsg "$ls  vmkernel nic policy: $vknics"
         tracemsg "$ls  vmkernel load balance: $vkload"
         tracemsg "$ls  vmkernel comment: $vkcomment"
         
         if [ "$vkip" == "none" ]; then
            warnmsg "$ls  cannot find IP for vmkernel interface - ignore config line"
            continue
         fi
         
         local vmkname="VMk"
         pgname="$vmkname - s$vsnr v$vlannr"
         debmsg "$ls  port group name: $pgname"
         
         if [ $retc -eq 0 ]; then
            if [ "$vkflags" != "none" ]; then
               for flag in $vkflags; do 
                  setflag=$(echo $flag | /usr/bin/cut -c -1)
                  if [ "$setflag" == "f" ]; then
                     infmsg "$ls  => set fault tolerance"
                     setfault=1
                     pgname="$pgname f"
                  elif [ "$setflag" == "m" ]; then
                     if [ $vmotion -eq 0 ]; then
                        infmsg "$ls  => set vmotion"
                        setvmotion=1
                        pgname="$pgname m"
                        vmotion=1
                     else
                        errmsg "vMotion already set - please control you config - abort"
                        retc=99
                        break
                     fi
                  elif [ "$setflag" == "t" ]; then
                     infmsg "$ls  => set management traffic"
                     setmm="1"
                     pgname="$pgname t"
                  else
                     errmsg "unknown flag [$setflag] - ignore"
                  fi
               done # for flag ...
            else
               debmsg "$ls  no flags given and add to pg name"
            fi
         fi      
         
         if [ "$vkcomment" != "none" ]; then
            pgname="$pgname $vkcomment"
            debmsg "$ls  port group name: $pgname"
         fi
   
         if [ $retc -eq 0 ]; then
            tracemsg "$ls  vSwitch: vSwitch$vsnr"
            create_pg "$pgname" "vSwitch$vsnr"
            retc=$?
         fi
         
         if [ $retc -eq 0 ]; then
            tracemsg "$ls  vSwitch: vSwitch$vsnr"
            set_vlan "$vlannr" "$pgname" "vSwitch$vsnr"
            retc=$?
         fi
   
         if [ $retc -eq 0 ]; then
            set_ip "$vkip" "$vknm" "$pgname"
            retc=$?
         fi
         
         if [ $retc -eq 0 ]; then
            if [ "$vkgate" != "none" ]; then
               set_gw "$vkgate" "$vknm" "$vkip"
               retc=$?
            else
               debmsg "$ls  no gateway configure"
            fi
         fi
         
         if [ $retc -eq 0 ]; then
            if [ $setvmotion -eq 1 ]; then
               set_vmotion "$pgname"
               retc=$?
            else
               debmsg "$ls  no vmotion flag"
            fi   
         fi
   
         if [ $retc -eq 0 ]; then
            if [ $setfault -eq 1 ]; then
               set_ft "$pgname"
               retc=$?
            else
               debmsg "$ls  no fault tolerance flag"
            fi
         fi
   
         if [ $retc -eq 0 ]; then
            if [ "$setmm" == "1" ]; then
               set_mm "$pgname"
               retc=$?
            else
               debmsg "$ls  no management network traffic flag"
            fi
         fi
   
         if [ $retc -eq 0 ]; then
            if [ "$vknics" != "none" ]; then
               tracemsg "$ls  vSwitch: vSwitch$vsnr"
               set_pgnicpol "$vknics" "$pgname" "vSwitch$vsnr"
            else
               debmsg "$ls  no nic policy change"
            fi
         fi
   
         if [ $retc -eq 0 ]; then
            if [ "$vkload" != "none" ]; then
               tracemsg "$ls  vSwitch: vSwitch$vsnr"
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
infmsg "$ls  start main management network config"
do_vmm
retc=$?
infmsg "$ls  end configure main management network - rc=$retc"

if [ $retc -eq 0 ]; then
   infmsg "$ls  start vmkernel network config"
   do_vmk
   retc=$?
   infmsg "$ls  end configure vmkernel networks - rc=$retc"
fi
   
infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc
