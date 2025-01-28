#!/bin/sh

# https://github.com/jarnos/block-scroll-mod-x11/tree/awk
# Author: Jarno Suni (http://iki.fi/8) 2025
# Requires xinput 1.6.4 or newer.

set -e
export LC_ALL=C

readonly default_delta=400
delta=$default_delta # The default can be overridden by -d option with
# a decimal argument.

while :; do
	case $1 in
		-d)
			ok=t
			[ "$2" ] && {
				delta=$2
				printf '%s' "$delta" | grep -Exq '[0-9]+' || ok=
				shift
			} || ok=
			[ "$ok" ] || {
				printf 'ERROR: "-d" requires a decimal integer argument.\n' >&2
				exit 1
			}
			;;
		--)
			shift
			break
			;;
		-?*)
			printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
			;;
		*)
			break
	esac

	shift
done


[ "${1+x}" ] || {
	cat >&2 <<EOF
Usage: $0 [-d delta] pointer_device_name

Default value of delta is $default_delta. Delta should be greater than
the delay between sequential inertial scrolling events in 1/1000 seconds.

You may run the following test script and scroll down to determine
suitable minimum delta for your system:
xinput --test-xi2 --root |
awk -Winteractive '/RawButtonPress/{
getline;getline;t=$2;if(ot){print t-ot};ot=t}'
EOF
	exit 1
}

readonly pointer_id=pointer:"$1"
id=$(xinput list --id-only "$pointer_id")

readonly modkeys="Shift_L,Shift_R,Caps_Lock,Control_L,Control_R,Alt_L,\
Meta_L,Num_Lock,Super_L,Super_R,Super_L,Hyper_L,ISO_Level3_Shift,\
Mode_switch" # key symbols of modifiers

# Make sure to enable the pointer device on exit.
revert() {
	trap - EXIT
	xinput enable "$id"
	echo $(date) >>/tmp/date
}
trap 'revert' EXIT
trap 'trap - TERM INT; kill -- $pid; sleep 1; revert' TERM INT
trap '' HUP ALRM VTALRM PROF USR1 USR2

awk -Winteractive -v keylist="$modkeys" -v pointer="$id" -v delta="$delta" '
function init_keys(modsyms,  i,amodsyms,cmd) {
	split(modsyms, amodsyms, ",")
	for (i in amodsyms) aamodsyms[amodsyms[i]]
	cmd="xmodmap -pke"
	while ((cmd | getline) > 0){
		if ($4 in aamodsyms) keys[$2]
	}
	close(cmd)
}
BEGIN{
	init_keys(keylist)
	cmd="xinput test-xi2 --root"
	shell="/bin/sh"
	while(status=(cmd|getline) > 0) {
		if(/^EVENT/){type=$3; cmd|getline; if($1!="device:")continue
			cmd|getline; if($1!="time:"){exit 2}; time=$2; cmd|getline
			if(type==13){ # RawKeyPress
				if($2 in keys){
					if(!paused && time - scrolltime < delta){
						print "xinput disable " pointer | shell
						fflush(shell); paused=1
					}
				}
			} else
			if(type==14){ # RawKeyRelease
				if($2 in keys){
					if(keys_down)--keys_down
					if(paused && !keys_down){
						print "xinput enable " pointer | shell
						fflush(shell); paused=0
					}
				}
			} else
			if(type==15){ # RawButtonPress
				if(!paused && $2>=4)scrolltime=time # scroll event
			}
		}
	}
	close(cmd)
	if(status < 0){
		print "Unknown error - ", status  > "/dev/stderr"
	}else{
		print "Error: running \""cmd"\" failed. Maybe it is running already." > "/dev/stderr"
	}
	exit 1
}
' &
pid=$!
wait $pid
