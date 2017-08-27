#!/bin/sh
#
#   sub_98_vc.sh - join vc
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
ver="1.02 - 25.3.2014"
retc=0
me=`basename $0`
ls="  "
esxenv="none"

. /store/fsi/viconf.sh
. $kspath"/tools/fsifunc.sh"

infmsg "$ls ESXi - $me $ver"

if [ "$esxenv" != "none" ] ; then
  infmsg "$ls  found env script for $esxenv"
  swconf="$kspath/sub/sub-98_vc-$esxenv.sh"
  infmsg "$ls  search for join vc for environement"
  debmsg "$ls   ==> script: $swconf"
  if [ -f $swconf ] ; then
      infmsg "$ls  found env script - run it"
      $swconf
      retc=$?
  else
      warnmsg "$ls  no script found for $esxenv - try default"
      swconf="$kspath/sub/sub-98_vc-default.sh"
      infmsg "$ls  search for join vc default config"
      debmsg "$ls   ==> script: $swconf"
      if [ -f $swconf ] ; then
          infmsg "$ls  found env script - run it"
          $swconf
          retc=$?
      else
          warnmsg "$ls  no default script found - cannot join virtual center"
      fi
  fi
else
   warnmsg "$ls  unknown vi environment -try default"
   swconf="$kspath/sub/sub-98_vc-default.sh"
   infmsg "$ls  search for join vc default config"
   debmsg "$ls   ==> script: $swconf"
   if [ -f $swconf ] ; then
      infmsg "$ls  found env script - run it"
      $swconf
      retc=$?
   else
      warnmsg "$ls  no default script found - cannot join virtual center"
   fi
fi


infmsg "$ls ESXi - $me $ver rc=$retc"
exit $retc