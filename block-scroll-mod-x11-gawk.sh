#!/bin/sh

# https://github.com/jarnos/block-scroll-mod-x11/tree/gawk
# Author: Jarno Suni (http://iki.fi/8) 2020

set -e
export LC_ALL=C

# NOTE: uses time extension for GNU awk. The extension will not work
# after version 5.1, see
# https://www.gnu.org/software/gawk/manual/html_node/Extension-Sample-Time.html

# Check, if gettimeofday() is supported
gawk -l time 'BEGIN{
	if(gettimeofday()==-1){print ERRNO > "/dev/stderr"; exit 1}
}'

readonly default_delta=0.1
delta=$default_delta # The default can be overridden by -d option with
# a decimal argument.

while :; do
	case $1 in
		-d)
			ok=t
			[ "$2" ] && {
				delta=$2
				echo $delta | grep -Exq '[0-9]+|[0-9]*\.[0-9]+' || ok=
				shift
			} || ok=
			[ "$ok" ] || {
				printf 'ERROR: "-d" requires a decimal argument.\n' >&2
				exit 1
			}
			;;
		--)
			shift; break
			;;
		-?*)
			printf 'ERROR: Invalid option: %s\n' "$1" >&2
			exit 1
			;;
		*)
			break
	esac

	shift
done


[ "${1+x}" ] || {
	cat >&2 <<EOF
Usage: $0 [-d delta] pointer_device_name

You can find the pointer device name of the device causing inertial
scrolling in the output of command
xinput list

Default value of delta is $default_delta. Delta should be greater than
the delay between sequential inertial scrolling events in seconds.

You may run the following test script and scroll down to determine
suitable minimum delta for your system:
xinput --test-xi2 --root | gawk -l time '
BEGIN{ot=gettimeofday()}
/RawButtonPress/{nt=gettimeofday();print nt-ot; ot=nt}'
EOF
	exit 1
}

readonly pointer_id=pointer:"$1"
# check validity
xinput list --id-only "$pointer_id" >/dev/null

readonly modkeys="Shift_L,Shift_R,Caps_Lock,Control_L,Control_R,Alt_L,\
Meta_L,Num_Lock,Super_L,Super_R,Super_L,Hyper_L,ISO_Level3_Shift,\
Mode_switch" # key symbols of modifiers

# Make sure to enable the pointer device on exit.
revert() {
	trap - EXIT
	[ "${pid+x}" ] && kill $pid 2>/dev/null || :
	xinput enable "$pointer_id"
}
trap 'revert' EXIT
trap 'revert; trap - INT; kill -s INT $$' INT
trap 'revert; trap - TERM; kill $$' TERM
trap '' HUP ALRM VTALRM PROF USR2
trap 'exit 1' USR1

{ xinput test-xi2 --root 2>/dev/null || {
	printf '%s\n%s\n' 'ERROR: "xinput test-xi2 --root" failed.' \
	'Maybe another instance is running already.' >&2;
	kill -s USR1 $$
} } | gawk -l time -v keylist="$modkeys" '
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
}
/^EVENT/{type=$3;getline;getline
	switch (type) {
	case 13: # RawKeyPress
		if($2 in keys){
			++keys_down
			if(!paused && gettimeofday() - scrolltime < delta){
				system("xinput disable \""pointer"\""); paused=1
			}
		}
		break
	case 14: # RawKeyRelease
		if($2 in keys){
			if(keys_down)--keys_down
			if(paused && !keys_down){
				system("xinput enable \""pointer"\""); paused=0
			}
		}
		break
	case 15: # RawButtonPress
		if(!paused && $2>=4)scrolltime=gettimeofday() # scroll event
	}
}
' pointer="$pointer_id" delta="$delta"
