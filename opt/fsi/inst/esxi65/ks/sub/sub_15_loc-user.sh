#!/bin/sh
#
#   sub_15_loc-user.sh - Add User
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
ver="1.05.22 - 29.10.2014"
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
userfound=0
managed_entity="vim.Folder:ha-folder-root"

while read line; do
  userline=$(echo $line| cut -c -6)
  user="none"
  pw="none"
  group="none"
  comment="none"
  homedir="none"
  role="none"
  options=""
  if [ "$userline" == "#user:" ] ; then
     user=$(echo $line| cut -d ":" -f 2 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     tracemsg "$ls  ==> user: [$user]"
     pw=$(echo $line| cut -d ":" -f 3 | awk '{$1=$1;print}' )
     tracemsg "$ls   pw: [$pw]"
     group=$(echo $line| cut -d ":" -f 4 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     if [ "$group" == "" ]; then
        group="none"    # keine Gruppe angegeben
     fi
     tracemsg "$ls   group: [$group]"

     tracemsg "$ls   Search comment ..."
     comment=$(echo $line| cut -d ":" -f 5 | awk '{$1=$1;print}' )
     if [ "$comment" == "" ]; then
        comment="none"
     fi
     tracemsg "$ls   comment: [$comment]"
     
     homedir=$(echo $line| cut -d ":" -f 6 | awk '{print tolower($0)}' | awk '{$1=$1;print}' )
     if [ "$homedir" == "" ]; then
         debmsg "$ls   no home dir config found - take none"
         homedir="none"
     elif [ "$homedir" == "yes" ]; then
         debmsg "$ls   configure user home dir"
     else
         debmsg "$ls   found home dir config [$homedir] => set to none"
         homedir="none"
     fi   
     tracemsg "$ls   homedir: [$homedir]"
     
     role=$(echo $line| cut -d ":" -f 7 | awk '{$1=$1;print}' )
     if [ "$role" == "" ]; then
        role="none"
     else
        tracemsg "$ls   test if role [$role] exist"
        existrole=$(vim-cmd vimsvc/auth/roles | awk '/ name =/ {print $3}'| sed 's/,//;s/"//g' | grep ^$role$)
        existrc=$?
        if [ $existrc -eq 1 ]; then
            errmsg "role $role does not exist - abort"
            retc=99
            break 
        fi
     fi
     tracemsg "$ls   role: [$role]"
     
     tracemsg "$ls   => all settings ok ?"
     if [ "$user" == "none" ]; then
        warnmsg "$ls   no user found -> ignore"
     else
        debmsg "$ls    configure user : $user"
        if [ "$pw" == "none" ]; then
           warnmsg "$ls    no pw define - ignore"
        else
           debmsg "$ls    find pw : $pw"
           homepath="/store/fsi/home/$user"
           
           existuser=$(grep ^$user: /etc/passwd)
           existuserrc=$?
           if [ $existuserrc -eq 0 ]; then
               infmsg "$ls    user exist - delete first"

               OUTPUT=$(2>&1 vim-cmd vimsvc/auth/entity_permissions $managed_entity | grep "principal=\"$user\"")
               existentity=$?
               if [ $existentity -eq 0 ]; then
                  debmsg "$ls     delete entity"
                  cmd="vim-cmd vimsvc/auth/entity_permission_remove $managed_entity $user"
                  tracemsg "$ls     => cmd: $cmd"
                  OUTPUT=$(2>&1 $cmd)
                  retc=$?
                  if [ $retc -ne 0 ]; then
                     tracemsg "$ls    rc=$retc [$OUTPUT]"
                     retc=0
                  fi
               fi

               if [ $retc -eq 0 ]; then
                  if [ $esximver -eq 4 ]; then
                     cmd="/usr/sbin/userdel $user"
                     tracemsg "$ls     => cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        warnmsg "$ls    [$OUTPUT]"
                        retc=0
                     fi
                     
                  elif [ $esximver -eq 5 ]; then
                     cmd="/usr/lib/vmware/auth/bin/deluser $user"
                     tracemsg "$ls     => cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        warnmsg "$ls    [$OUTPUT]"
                        retc=0
                     fi
                  elif [ $esximver -eq 6 ]; then
                     cmd="/usr/lib/vmware/auth/bin/deluser $user"
                     tracemsg "$ls     => cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        errmsg "rc=$retc [$OUTPUT]"
                        retc=0
                     fi
                  fi
               fi
               
               if [ $retc -eq 0 ]; then
                  infmsg "$ls    user deleted"
                  if [ -d $homepath ]; then
                     infmsg "$ls   remove existing homedir"
                     cmd="rm -fr $homepath"
                     tracemsg "$ls     => cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -eq 0 ]; then
                        infmsg "$ls   removed"
                     else
                        errmsg "removing homedir - abort"
                        errmsg "rc=$retc [$OUTPUT]"
                        break
                     fi
                  else
                     infmsg "$ls   no user dir exist"
                  fi
               else
                  errmsg "deleting user $user"
                  break
               fi
               existuser=$(grep ^$user: /etc/passwd)
               existuserrc=$?
           fi

           if [ $existuserrc -eq 1 ]; then
              debmsg "$ls   user $user does not exist - create"
           
              tracemsg "$ls    inc user found"
              userfound=$((userfound+1))
              tracemsg "$ls    userfound: $userfound"
              infmsg "$ls    find user $user - start configure"
              options=""
              if [ "$group" == "none" ]; then
                 if [ $esximver -eq 4 ]; then
                    infmsg "$ls     - without group (-n)"
                    options="$options -n"
                 elif [ $esximver -eq 5 ]; then
                    infmsg "$ls     - without group"
                 elif [ $esximver -eq 6 ]; then
                    infmsg "$ls     - without group"
                 fi
                 tracemsg "$ls      options: $options"
              else
                 debmsg "$ls     create group"
                 if [ $esximver -eq 4 ]; then
                    infmsg "$ls     - with group: $group (-g)"
                    options="$options -g $group"
                    grep ^$group: /etc/group > /dev/null || groupadd $group
                    retc=$?
                    basecmd="/usr/sbin/useradd "
                 elif [ $esximver -eq 5 ]; then
                    infmsg "$ls     - with group: $group (-G)"
                    options="$options -G $group"
                    grep ^$group: /etc/group > /dev/null || /usr/lib/vmware/auth/bin/addgroup $group
                    retc=$?
                    basecmd="/usr/lib/vmware/auth/bin/adduser "
                 elif [ $esximver -eq 6 ]; then
                    infmsg "$ls     - with group: $group (-G)"
                    options="$options -G $group"
                    grep ^$group: /etc/group > /dev/null || /usr/lib/vmware/auth/bin/addgroup $group
                    retc=$?
                    basecmd="/usr/lib/vmware/auth/bin/adduser "
                 fi
                 if [ $retc -ne 0 ]; then
                    errmsg "cannot create group $OUTPUT - abort"
                    break
                 fi
                 tracemsg "$ls      options: $options"
              fi
                 

              if [ "$comment" == "none" ]; then
                 infmsg "$ls     - without comment"
              else
                 if [ $esximver -eq 4 ]; then
                    infmsg "$ls     - without comment (-c)"
                    options="$options -c \"$comment\""
                 elif [ $esximver -eq 5 ]; then
                     infmsg "$ls     - without comment (-g)"
                     options="$options -g \"$comment\""
                 elif [ $esximver -eq 6 ]; then
                     infmsg "$ls     - without comment (-g)"
                     options="$options -g \"$comment\""
                 fi
              
                 tracemsg "$ls      options: $options"
              fi
                 
              if [ "$homedir" == "yes" ]; then
                 infmsg "$ls   create home dir $homepath"
                 OUTPUT=$(2>&1 mkdir -p $homepath)
                 retc=$?
                 
                 if [ $retc -eq 0 ]; then
                     debmsg "$ls    set user options with home dir"
                    if [ $esximver -eq 4 ]; then
                        infmsg "$ls     - with home dir (-M -d)"
                        options="$options -M -d $homepath -s /bin/ash"
                    elif [ $esximver -eq 5 ]; then
                        infmsg "$ls     - with home dir (-H -h)"
                        options="$options -H -h $homepath -s /bin/ash"
                    elif [ $esximver -eq 6 ]; then
                        infmsg "$ls     - with home dir (-H -h)"
                        options="$options -H -h $homepath -s /bin/ash"
                    fi
                  else
                     errmsg "cannot create user dir - abort"
                     break
                  fi
              else
                  infmsg "$ls     set user options without home dir"
                  if [ $esximver -eq 4 ]; then
                      infmsg "$ls     - without home dir (-M -d /)"
                      options="$options -M -d / -s /sbin/nologin"
                  elif [ $esximver -eq 5 ]; then
                      infmsg "$ls     - with home dir (-H -h /)"
                      options="$options -H -h / -s /sbin/nologin"
                  elif [ $esximver -eq 6 ]; then
                      infmsg "$ls     - with home dir (-H -h /)"
                      options="$options -H -h / -s /sbin/nologin"
                  fi
              fi    
              tracemsg "$ls      options: $options"
              
              if [ $retc -eq 0 ]; then
                 if [ $esximver -eq 5 ]; then
                     infmsg "$ls     -D for do not enter password"
                     options="$options -D"
                 elif [ $esximver -eq 6 ]; then
                     infmsg "$ls     -D for do not enter password"
                     options="$options -D"
                 fi

                 cmd="$basecmd $options $user"
                 tracemsg "$ls     => cmd: [$cmd]"
                 infmsg "$ls    create user now"
                 OUTPUT=$(eval $cmd)
                 retc=$?
                 if [ $retc -ne 0 ]; then
                    errmsg "cannot install user [$user] - abort"
                    errmsg "cmd: [$cmd]"
                    errmsg "[$OUTPUT]"
                    break
                 fi
              fi
              
#              if [ $retc -eq 0 ]; then
#                 if [ $esximver -eq 4 ]; then
#                    infmsg "$ls   set login shell"
#                    OUTPUT=$(2>&1 usermod -s /bin/ash $user)
#                    retc=$?
#                    if [ $retc -ne 0 ]; then
#                       errmsg "cannot change login shell $OUTPUT - abort"
#                    fi
#                 fi
#              fi
              
              
              if [ $retc -eq 0 ]; then
                 if [ "$homedir" == "yes" ]; then
                    infmsg "$ls    set access to home dir"
                    cmd="chown $user $homepath"
                    tracemsg "$ls    cmd: $cmd"
                    OUTPUT=$(2>&1 $cmd)
                    retc=$?
                    if [ $retc -ne 0 ]; then
                       errmsg "cannot set access to home dir $OUTPUT - abort"
                       break
                    fi
                 fi
              fi
                                                 
              if [ $retc -eq 0 ]; then
                 infmsg "$ls    set pw"
                 OUTPUT=$(2>&1 echo $pw | passwd --stdin $user)
                 retc=$?
                 if [ $retc -ne 0 ]; then
                    errmsg "cannot set password $OUTPUT - abort"
                    break
                 else
                    infmsg "$ls    ok"
                 fi
              fi

              if [ $retc -eq 0 ]; then
                  if [ "$role" == "none" ]; then
                     infmsg "$ls   user $user has no role"
                  else 
                     infmsg "$ls   user $user has role [$role] configure"
                     cmd="vim-cmd vimsvc/auth/entity_permission_add $managed_entity $user false $role true"
                     tracemsg "$ls   cmd: $cmd"
                     OUTPUT=$(2>&1 $cmd)
                     retc=$?
                     if [ $retc -ne 0 ]; then
                        errmsg "cannot set access to home dir $OUTPUT - abort"
                        break
                     fi
                  fi
              fi

           fi   
              
        fi                                   
     fi
  fi
done < $ksfile

if [ $retc -eq 0 ]; then
   if [ $userfound -eq 0 ]; then
      infmsg "$ls   => no user to add found"
   else
      infmsg "$ls   => $userfound user configure"
   fi
fi

infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc

