#!/bin/sh
#
#   sub_14_loc-roles.sh - Local Roles
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
ver="1.00.05 - 29.10.2014"
retc=0
ls="  "
me=`basename $0`

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
debug="trace"
infmsg "$ls ESXi - $me $ver"

command=""
rolefound=0

while read line; do
  userline=$(echo $line| cut -c -6)
  rolename="none"
  roleprivs="none"
  if [ "$userline" == "#role:" ] ; then
     rolename=$(echo $line| cut -d ":" -f 2 | awk '{$1=$1;print}' )
     roleprivs=$(echo $line| cut -d ":" -f 3 | awk '{$1=$1;print}' )
     if [ "$rolename" == "" ]; then
        rolename="none" 
     fi
     tracemsg "$ls  ==> role name: [$rolename]"
     tracemsg "$ls   role privs: [$roleprivs]"
     
     tracemsg "$ls   all settings ok ?"
     if [ "$rolename" == "none" ]; then
        warnmsg "$ls   no role name found -> ignore"
     else
        debmsg "$ls  configure role : $rolename"
        if [ "$roleprivs" == "none" ]; then
           warnmsg "$ls   no privileges define -> ignore"
        else
           debmsg "$ls   privs : $roleprivs"
           tracemsg "$ls   inc role found"
           rolefound=$((rolefound+1))
           tracemsg "$ls   rolefound: $rolefound"
           infmsg "$ls   find role $rolename - start configure"
           if [ $retc -eq 0 ]; then
               existrole=$(vim-cmd vimsvc/auth/roles | awk '/ name =/ {print $3}'| sed 's/,//;s/"//g' | grep -E ^$rolename$)
               existrc=$?
               if [ $existrc -eq 0 ]; then
                  infmsg "$ls   role [$rolename] already exist - remove first"
                  cmd="vim-cmd vimsvc/auth/role_remove $rolename"
                  tracemsg "$ls     cmd: $cmd"
                  OUTPUT=$(2>&1 $cmd)
                  retc=$?
                  if [ $retc -ne 0 ]; then
                     errmsg "$ls    [$OUTPUT]"
                  else
                     existrole=$(vim-cmd vimsvc/auth/roles | awk '/ name =/ {print $3}'| sed 's/,//;s/"//g' | grep -E ^$rolename$)
                     existrc=$?
                  fi
               fi

               if [ $retc -eq 0 ]; then
                  if [ $existrc -eq 1 ]; then
                     infmsg "$ls   create role [$role] ..."
                     cmd="vim-cmd vimsvc/auth/role_add $rolename $roleprivs"
                     tracemsg "$ls     cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        errmsg "=> [$OUTPUT]"
                     else
                        infmsg "$ls   role $rolename created" 
                     fi
                  fi   
               fi      
            fi
        fi
      fi
  fi
done < $ksfile

if [ $retc -eq 0 ]; then
   if [ $rolefound -eq 0 ]; then
      infmsg "$ls   => no role to add found"
   else
      infmsg "$ls   => $rolefound roles configure"
   fi
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc

