# linuxmuster shell helperfunctions
#
# Thomas Schmitt
# <tschmitt@linuxmuster.de>
# GPL v3
#
# $Id: helperfunctions.sh 1334 2012-07-20 12:03:39Z tschmitt $
#

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# source network settings
[ -f "$NETWORKSETTINGS" ] && . $NETWORKSETTINGS

# lockfile
lockflag=/tmp/.linuxmuster.lock

# date & time
[ -e /bin/date ] && DATETIME=`date +%y%m%d-%H%M%S`


####################
# common functions #
####################

# parse command line options
getopt() {
  until [ -z "$1" ]
  do
    if [ ${1:0:2} = "--" ]
    then
        tmp=${1:2}               # Strip off leading '--' . . .
        parameter=${tmp%%=*}     # Extract name.
        value=${tmp##*=}         # Extract value.
        eval $parameter=$value
#        [ -z "$parameter" ] && parameter=yes
    fi
    shift
  done
}

# cancel on error, $1 = Message, $2 logfile
cancel() {
  echo "$1"
  [ -e "$lockflag" ] && rm -f $lockflag
  [ -n "$2" ] && echo "$DATETIME: $1" >> $2
  exit 1
}

# check lockfiles, wait a minute whether it will be freed
checklock() {
  if [ -e "$lockflag" ]; then
    echo "Found lockfile $lockflag!"
    n=0
    while [[ $n -lt $TIMEOUT ]]; do
      remaining=$(($(($TIMEOUT-$n))*10))
      echo "Remaining $remaining seconds to wait ..."
      sleep 1
      if [ ! -e "$lockflag" ]; then
        touch $lockflag || return 1
        echo "Lockfile released!"
        return 0
      fi
      let n+=1
    done
    echo "Timed out! Exiting!"
    return 1
  else
    touch $lockflag || return 1
  fi
  return 0
}


# test if variable is an integer
isinteger () {
  [ $# -eq 1 ] || return 1

  case $1 in
  *[!0-9]*|"") return 1;;
            *) return 0;;
  esac
} # isinteger


# escape special characters
esc_spec_chars() {
	RET="$1"
	RET=${RET// /\\ }
	RET=${RET//(/\\(}
	RET=${RET//)/\\)}
	RET=${RET//$/\\$}
	RET=${RET//\!/\\!}
	RET=${RET//\&/\\&}
}


# backup up files gzipped to /var/backup/linuxmuster
backup_file() {
	[ -z "$1" ] && return 1
	[ -e "$1" ] || return 1
	echo "Backing up $1 ..."
	origfile=${1#\/}
	backupfile=$BACKUPDIR/$origfile-$DATETIME.gz
	origpath=`dirname $1`
	origpath=${origpath#\/}
	[ -d "$BACKUPDIR/$origpath" ] || mkdir -p $BACKUPDIR/$origpath
	gzip -c $1 > $backupfile || return 1
	return 0
}

# check free space: check_free_space path size
check_free_space(){
	local cpath=$1
	local csize=$2
	echo -n "Pruefe freien Platz unter $cpath: " | tee -a $LOGFILE
	local available=`LANG=C df -P $cpath | grep -v Filesystem | awk '{ print $4 }' | tail -1`
	echo -n "${available}kb sind verfuegbar ... " | tee -a $LOGFILE
	if [ $available -ge $csize ]; then
		echo "Ok!" | tee -a $LOGFILE
		echo
		return 0
	else
		echo "zu wenig! Sie benoetigen mindestens ${csize}kb!" | tee -a $LOGFILE
		return 1
	fi
}

#######################
# config file editing #
#######################

addto_file()
{
	# Parameter 1 original file
	# Parameter 2 changes file
	# Parameter 3 search pattern after that content of changes file will be inserted
 local ofile="$1"
 local cfile="$2"
 local pattern="$3"
 local tfile="/var/tmp/addto_file.$$"
	sed ''/$pattern/' r '$cfile'' <$ofile > $tfile || return 1
	cp $tfile $ofile
	rm $tfile
	return 0
}

removefrom_file()
{
	# Parameter 1 original file
	# Parameter 2 search pattern e.g. /\;### linuxmuster - begin ###/,/\;### linuxmuster - end ###/
 local ofile="$1"
 local pattern="$2"
 local tfile="/var/tmp/removefrom_file.$$"
	sed "$pattern"d <$ofile > $tfile || return 1
	cp $tfile $ofile
	rm $tfile
	return 0
}

##########################
# check parameter values #
##########################

# check valid domain name
validdomain() {
 [ -z "$1" ] && return 1
 tolower "$1"
  if (expr match "$RET" '\([abcdefghijklmnopqrstuvwxyz0-9\-]\+\(\.[abcdefghijklmnopqrstuvwxyz0-9\-]\+\)\+$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# check valid ip
validip() {
  if (expr match "$1"  '\(\([1-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([0-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([0-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)\.\([1-9]\|[1-9][0-9]\|1[0-9]\{2\}\|2[0-4][0-9]\|25[0-4]\)$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# test valid mac address syntax
validmac() {
  [ -z "$1" ] && return 1
  [ `expr length $1` -ne "17" ] && return 1
  if (expr match "$1" '\([a-fA-F0-9-][a-fA-F0-9-]\+\(\:[a-fA-F0-9-][a-fA-F0-9-]\+\)\+$\)') &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# test for valid hostname
validhostname() {
 [ -z "$1" ] && return 1
 tolower "$1"
 if (expr match "$RET" '\([abcdefghijklmnopqrstuvwxyz0-9\-]\+$\)') &> /dev/null; then
  return 0
 else
  return 1
 fi
}


#######################
# workstation related #
#######################

# extract ip address from file $WIMPORTDATA
get_ip() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  local pattern="$1"
  if validmac "$pattern"; then
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $4 " " $5 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  else # assume hostname
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $2 " " $5 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  fi
  return 0
}

# extract room ip address from file $WIMPORTDATA
get_room_ip() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  local pattern="$1"
  RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $1 " " $5 }' | grep -i ^"$pattern " | tail -1 | awk '{ print $2 }'` &> /dev/null
  return 0
}

# extract mac address from file $WIMPORTDATA
get_mac() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  local pattern="$1"
  if validip "$pattern"; then
   pattern="${pattern//./\\.}"
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $5 " " $4 }' | grep ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  else # assume hostname
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $2 " " $4 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  fi
  [ -n "$RET" ] && toupper "$RET"
  return 0
}

# extract hostname from file $WIMPORTDATA
get_hostname() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  local pattern="$1"
  if validip "$pattern"; then
   pattern="${pattern//./\\.}"
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $5 " " $2 }' | grep ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  elif validmac "$pattern"; then
   RET=`grep -v ^# $WIMPORTDATA awk -F\; '{ print $4 " " $2 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  else # assume hostname
   RET=`grep -v ^# $WIMPORTDATA | tr A-Z a-z | awk -F\; '{ print $2 }' | grep -wi ^"$pattern" | head -1` &> /dev/null
  fi
  [ -n "$RET" ] && tolower "$RET"
  return 0
}

# extract room from file $WIMPORTDATA
get_room() {
  unset RET
  [ -f "$WIMPORTDATA" ] || return 1
  local pattern="$1"
  if validip "$pattern"; then
   pattern="${1//./\\.}"
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $5 " " $1 }' | grep ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  elif validmac "$pattern"; then
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $4 " " $1 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  else # assume hostname
   RET=`grep -v ^# $WIMPORTDATA | awk -F\; '{ print $2 " " $1 }' | grep -i ^"$pattern " | awk '{ print $2 }'` &> /dev/null
  fi
  [ -n "$RET" ] && tolower "$RET"
  return 0
}

# needed by internet & intranet on off scripts
get_maclist() {
  # parse maclist
  if [ -n "$maclist" ]; then

    n=0
    OIFS=$IFS
    IFS=","
    for i in $maclist; do
      if validmac $i; then
        mac[$n]="$(echo $i | tr a-z A-Z)"
      else
        continue
      fi
      let n+=1
    done
    IFS=$OIFS
    nr_of_macs=$n
    [[ $nr_of_macs -eq 0 ]] && cancel "No valid mac addresses found!"

  else # parse hostlist

    n=0
    OIFS=$IFS
    IFS=","
    for i in $hostlist; do
      host[$n]="$(echo $i | tr A-Z a-z)"
      let n+=1
    done
    IFS=$OIFS
    nr_of_hosts=$n
    [[ $nr_of_hosts -eq 0 ]] && cancel "No hostnames found!"

    n=0; m=0
    while [[ $n -lt $nr_of_hosts ]]; do
      get_mac ${host[$n]} || cancel "Read failure! Cannot determine mac address!"
      if validmac $RET; then
        mac[$m]=$RET
        let m+=1
      fi
      let n+=1
    done
    nr_of_macs=$m
    [[ $nr_of_macs -eq 0 ]] && cancel "No mac addresses found!"

  fi

  return 0
}


#######################
# IPCop communication #
#######################

# check if urlfilter is active
check_urlfilter() {
  # get advanced proxy settings
  get_ipcop /var/ipcop/proxy/advanced/settings $CACHEDIR/proxy.advanced.settings || cancel "Cannot download proxy advanced settings!"
  . $CACHEDIR/proxy.advanced.settings || cancel "Cannot read $CACHEDIR/proxy.advanced.settings!"
  rm -f $CACHEDIR/proxy.advanced.settings
  [ "$ENABLE_FILTER" = "on" ] || return 1
  return 0
}

# execute a command on ipcop
exec_ipcop() {
  ssh -p 222 root@$ipcopip $* &> /dev/null || return 1
  return 0
}

# fetch file from ipcop
get_ipcop() {
  scp -P 222 root@$ipcopip:$1 $2 &> /dev/null || return 1
  return 0
}

# upload file to ipcop
put_ipcop() {
  scp -P 222 $1 root@$ipcopip:$2 &> /dev/null || return 1
  return 0
}


#################
# nic setup     #
#################
discover_nics() {

 n=0
 # fetch all interfaces and their macs from /sys
 for i in /sys/class/net/bond* /sys/class/net/eth* /sys/class/net/wlan* /sys/class/net/intern /sys/class/net/extern /sys/class/net/dmz; do

  [ -e $i/address ] || continue

  iface[$n]="$(basename $i)"
  [ -z "${iface[$n]}" ] && continue

  address[$n]=`head -1 $i/address`
  [ `expr length ${address[$n]}` -eq 17 ] || continue

  toupper ${address[$n]}
  address[$n]=$RET
  id=`ls -1 -d $i/device/driver/0000:* 2> /dev/null`
  id=`echo $id | awk '{ print $1 }' -`
  id=${id#$i/device/driver/}
  id=${id#0000:}

  if [ -n "$id" ]; then
   tmodel=`lspci | grep $id | awk -F: '{ print $3 $4 }' -`
   tmodel=`expr "$tmodel" : '[[:space:]]*\(.*\)[[:space:]]*$'`
   tmodel=${tmodel// /_}
   model[$n]=${tmodel:0:38}
  else
   model[$n]="Unrecognized_Ethernet_Controller"
  fi

  n=$(( $n + 1 ))

 done

 nr_of_nics=$n

} # discover_nics


create_nic_choices() {

 n=0
 unset NIC_CHOICES
 while [ $n -lt $nr_of_nics ]; do
  menu[$n]="${iface[$n]} ${model[$n]} ${address[$n]}"
  if [ -n "$NIC_CHOICES" ]; then
   NIC_CHOICES="${NIC_CHOICES}, ${menu[$n]}"
  else
   NIC_CHOICES="${menu[$n]}"
  fi
  let n+=1
 done
 NIC_DEFAULT="${menu[0]}"
 NIC_CHOICES="$NIC_CHOICES, , Abbrechen"

} # create_nic_choices


assign_nics() {

 # first fetch all nics and macs from the system
 nr_of_nics=0
 discover_nics

 # no nic no fun
 if [ $nr_of_nics -lt 1 ]; then
  echo " Sorry, no NIC found! Aborting!"
  exit 1
 fi

 # substitute nicmenu descritpion
 NIC_DESC="Welche Netzwerkkarte ist mit dem internen Netz verbunden? \
           Waehlen Sie die entsprechende Karte mit den Pfeiltasten aus \
           und starten Sie dann die Serverkonfiguration mit ENTER."
 db_subst linuxmuster-base/nicmenu nic_desc $NIC_DESC

 # compute menu entries
 create_nic_choices

 # build menu
 db_fset linuxmuster-base/nicmenu seen false
 db_subst linuxmuster-base/nicmenu nic_choices $NIC_CHOICES

 # menu input
 db_set linuxmuster-base/nicmenu $NIC_DEFAULT || true
 db_input $PRIORITY linuxmuster-base/nicmenu || true
 db_go
 db_get linuxmuster-base/nicmenu || true
 iface_lan="$(echo "$RET" | awk '{ print $1 }')"

 [ "$iface_lan" = "Abbrechen" ] && exit 1

 db_set linuxmuster-base/iface_lan $iface_lan || true
 db_go

 # write iface to network.settings
 if [ -e "$NETWORKSETTINGS" ]; then
  if grep -q ^iface_lan $NETWORKSETTINGS; then
   sed -e "s|^iface_lan=.*|iface_lan=$iface_lan|" -i $NETWORKSETTINGS
  else
   echo "iface_lan=$iface_lan" >> $NETWORKSETTINGS
  fi
 fi

} # assign_nics


########
# ldap #
########

# get login by id
# uid=$1
get_login_by_id() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select uid from userdata where id = '$1';"`
}

# get uid number for user
# username=$1
get_uidnumber() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select uidnumber from posix_account where uid = '$1';"`
}

# get group number for group name
# group=$1
get_gidnumber() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select gidnumber from groups where gid = '$1';"`
}

# get user's primary group
# username=$1
get_pgroup() {
  unset T_RET
  unset RET
  T_RET=`psql -U ldap -d ldap -t -c "select gidnumber from posix_account where uid = '$1';"`
  RET=`psql -U ldap -d ldap -t -c "select gid from groups where gidnumber = '$T_RET';"`
}

# get homedir for user
# username=$1
get_homedir() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select homedirectory from posix_account where uid = '$1';"`
}

# get realname for user
# username=$1
get_realname() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select gecos from posix_account where uid = '$1';"`
}

# get primary group members from ldab db
# group=$1
get_pgroup_members() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select uid from memberdata where adminclass = '$1';"`
}

# get all group members from ldab db
# group=$1
get_group_members() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select uid from memberdata where adminclass = '$1' or gid = '$1';"`
}

# check if group is a project
# group=$1
check_project() {
  unset RET
  RET=`psql -U ldap -d ldap -t -c "select gid from projectdata where gid = '$1';"`
  strip_spaces $RET
  [ "$RET" = "$1" ] && return 0
  return 1
}

# check for valid group, group members and if teacher is set, for teacher membership
# group=$1, teacher=$2
check_group() {
  # check valid gid
  unset RET
  get_gidnumber $1
  [ -z "$RET" ] && return 1
  [ "$RET" -lt 10000 ] && return 1

  # fetch group members to $RET, return 1 if there are no members
  unset RET
  get_group_members $1 || return 1
  [ -z "$RET" ] && return 1

  # check if teacher is in group
  if [ -n "$2" ]; then
    if ! echo "$RET" | grep -qw $2; then
      return 1
    fi
  fi

  return 0
}

# get all host accounts from db
hosts_db() {
  local RET
  RET=`psql -U ldap -d ldap -t -c "select uid from posix_account where firstname = 'Exam';"`
  if [ -n "$RET" ]; then
	 	echo "$RET" | awk '{ print $1 }'
   return 0
  else
   return 1
  fi
}

# get all host accounts from ldap
hosts_ldap() {
  local RET
  RET=`ldapsearch -x -h localhost "(description=ExamAccount)" | grep ^uid\: | awk '{ print $2 }'`
  if [ -n "$RET" ]; then
		echo "$RET"
    return 0
  else
    return 1
  fi
}

# get all host accounts
machines_db() {
  local RET
  RET=`psql -U ldap -d ldap -t -c "select uid from posix_account where firstname = 'Computer';"`
  if [ -n "$RET" ]; then
		 echo "$RET" | awk '{ print $1 }'
   return 0
  else
   return 1
  fi
}

# get all host accounts from ldap
machines_ldap() {
  local RET
  RET=`ldapsearch -x -h localhost "(gidNumber=515)" | grep ^uid\: | awk '{ print $2 }'`
  if [ -n "$RET" ]; then
		echo "$RET"
    return 0
  else
    return 1
  fi
}

# get all user accounts
accounts_db() {
  local RET
  RET=`psql -U ldap -d ldap -t -c "select uid from posix_account where firstname <> 'Computer' and firstname <> 'Exam';"`
  if [ -n "$RET" ]; then
		 echo "$RET" | awk '{ print $1 }'
   return 0
  else
   return 1
  fi
}

# get all user accounts from ldap
accounts_ldap() {
  local RET
  RET=`ldapsearch -x -h localhost "(&(!(gidNumber=515))(!(description=ExamAccount)))" | grep ^uid\: | awk '{ print $2 }'`
  if [ -n "$RET" ]; then
		echo "$RET"
    return 0
  else
    return 1
  fi
}

# check if account exists
# username=$1
check_id() {
  unset RET
  [ -z "$1" ] && return 1
  RET=`psql -U ldap -d ldap -t -c "select uid from posix_account where uid = '$1';"`
  if [ -n "$RET" ]; then
    return 0
  else
    return 1
  fi
}

# check if user is teacher
# teacher=$1
check_teacher() {
  unset RET
  [ -z "$1" ] && return 1
  local RC=1
  get_group_members $TEACHERSGROUP
  if echo "$RET" | grep -qw $1; then
    RC=0
  fi
  unset RET
  return $RC
}

# check if user is admin
# admin=$1
check_admin() {
  unset RET
  [ -z "$1" ] && return 1
  local RC=1
  get_group_members $DOMADMINS
  if echo "$RET" | grep -qw $1; then
    RC=0
  fi
  unset RET
  return $RC
}


#################
# miscellanious #
#################

# stripping trailing and leading spaces
strip_spaces() {
  unset RET
  RET=`expr "$1" : '[[:space:]]*\(.*\)[[:space:]]*$'`
  return 0
}

# test if string is in string
stringinstring() {
  case "$2" in *$1*) return 0;; esac
  return 1
}

# checking if directory is empty, in that case it returns 0
check_empty_dir() {
  unset RET
  RET=$(ls -A1 $1 2>/dev/null | wc -l)
  [ "$RET" = "0" ] && return 0
  return 1
}

# check valid string without special characters
check_string() {
 tolower "$1"
 if (expr match "$RET" '\([abcdefghijklmnopqrstuvwxyz0-9\_\-]\+$\)') &> /dev/null; then
  return 0
 else
  return 1
 fi
}

# converting string to lower chars
tolower() {
  unset RET
  [ -z "$1" ] && return 1
  RET=`echo $1 | tr A-Z a-z`
}

# converting string to lower chars
toupper() {
  unset RET
  [ -z "$1" ] && return 1
  RET=`echo $1 | tr a-z A-Z`
}
