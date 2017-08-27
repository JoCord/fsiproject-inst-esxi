#
#   Function script for VI ESXi Installation
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
# Vars
export logfile="$vipath/viesxinst.log"
export hostname=$(hostname -s)
export remotelog="$kspath/log/$hostname.log"
export viinfopath="$kspath/log/info"
# write to file level
export debug="info"
export deb2scr="yes"          # write to screen

ismounted() {
   local ls="$ls  "
   local mook=0
   tracemsg "$ls func:ismounted start"
   debmsg "$ls  path exist ?"
   if [ -d $kspath ]; then
      infmsg "$ls  path exist - mounted"
      mook=1
   fi
   
   debmsg "$ls  esxi storage mount ?"
   tempmount=`esxcfg-nas -l | grep -i "nfs_fsi_$esxitree" | awk '{print $3}'`
   if [ "$fsimount" == "$tempmount" ]; then
      infmsg "$ls  esxi also reported mounted"
      mook=1
   fi
   
   tracemsg "$ls func:ismounted end - return: $mook"
   return $mook
}

# Logging
tracemsg() {
    if [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ] ; then
        logmsg "TRACE  :  $1" 
    fi
}
debmsg() {
    if [ "$debug" == "debug" ] || [ "$debug" == "trace" ] || [ "$debug" == "press" ] || [ "$debug" == "sleep" ]; then
        logmsg "DEBUG  :  $1"
    fi
}
warnmsg() {
    logmsg "WARN   :  $1"
}
infmsg() {
    logmsg "INFO   :  $1"
}
errmsg() {
    logmsg "ERROR  :  $1"
}
logmsg() {
   local timestamp=$(date +%H:%M:%S)
   local datetimestamp=$(date +%Y.%m.%d)"-"${timestamp}
   local progname=${0##*/}
   local pidnr=$$
   if [ "$deb2scr" == "yes" ]; then
     echo $timestamp "$1"
   fi
   printf "%-19s : %-6d - %-30s %s\n" $datetimestamp $pidnr $progname "$1" >>$logfile
   if [ -d "$kspath/log" ]; then
      printf "%-19s : %-6d - %-30s %s\n" $datetimestamp $pidnr $progname "$1" >>$remotelog
   fi
}

