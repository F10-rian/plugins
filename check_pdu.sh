#!/bin/bash
#
# Script Info
readonly PROGVERSION="Version 1.1"
readonly AUTHOR="Florian Seidel"
readonly PROGNAME="chech_pdu.sh"

# APC Temperature	.1.3.6.1.4.1.674.10903.200.2.200.150.2.2.1.5.1

# Variables

# Nagios/Icinga API Exit codes
readonly STATE_OK=0
readonly STATE_WARNING=1
readonly STATE_CRITICAL=2
readonly STATE_UNKNOWN=3

STATE=$STATE_OK
RETURNSTRING=""
PERFSTRING=""

# Help
function print_rev {
   # Print the revision number
   echo "$PROGNAME - $PROGVERSION"
}

function print_usage {
   # Print a short usage statement
   echo -e "Usage: $PROGNAME
   -H <PDU>
   -D <PDU Devicetype HP or APC>
   -v <SNMP Version 1 or 2c>
   -C <Community String>
   -M <Mode>
		temperature
   -u <unit>
   -w <Warning max Value in C>
   -c <Critical max Value in C>"
   echo -e "Example: $PROGNAME -H 192.168.13.13 -v 2c -C public -M -w 80 -c 90"
}

function print_requirements {
	echo -e "required Packages:
	bc
	sed"
}

function print_help {
   # Print detailed help information
   print_rev
   print_usage
   print_requirements
}

# Parse command line options
while getopts h:H:D:v:C:M:u:w:c:* option; do
	case $option in
	h)
	print_help
	exit 0
	;;
	H)
	IP=$OPTARG
	;;
	D)
	DEVICETYPE=$OPTARG
	;;
	v)
	VERSION=$OPTARG
	;;
	C)
	COMMUNITY=$OPTARG
	;;
	M)
	MODE=$OPTARG
	;;
	u)
	UNIT=$OPTARG
	;;
	w)
	WARNING=$OPTARG
	;;
	c)
	CRITICAL=$OPTARG
	;;
	*)
	print_help
	exit 0
	;;
	esac
done

function temperature(){
	case $DEVICETYPE in
		APC)
			RAW_TEMPERATURE=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.674.10903.200.2.200.150.2.2.1.5.1 -O v | awk '{print $2}'`
			TEMPERATURE=$(echo "scale=1; ${RAW_TEMPERATURE}/10" | bc)
			INT_TEMPERATURE=$(echo "${RAW_TEMPERATURE}/10" | bc)
		;;
		*)
			echo "device is not supported"
			print_help
			exit $STATE_UNKNOWN
		;;
	esac
	UNIT="C"
#	echo "${TEMPERATURE} ${UNIT}"

	if [ $WARNING -ge $CRITICAL ]
	then
		echo "critical value must be larger than warning"
		print_help
		exit $STATE_UNKNOWN
	fi

	if [ $CRITICAL -gt 100 ]
	then
		echo "hey dude, more than 100 degrees celsius is not good for any computer"
		print_help
                exit $STATE_UNKNOWN
        fi
			
	if [ ${WARNING} -gt ${INT_TEMPERATURE} ]
	then
		STATE=$STATE_OK
	elif [ $CRITICAL -le $INT_TEMPERATURE ]
	then
		STATE=$STATE_CRITICAL
	elif [ $WARNING -le $INT_TEMPERATURE ]
	then
		STATE=$STATE_WARNING
	else
		STATE=$STATE_UNKNOWN
	fi
	RETURNSTRING="Temperature: ${TEMPERATURE}${UNIT}"
	PERFSTRING="'Temperature'=${TEMPERATURE}${UNIT};$WARNING;$CRITICAL;0;100"
}

case $MODE in
	temperature) temperature
	;;
	*)
		echo "mode is not supported"
		print_help
		exit $STATE_UNKNOWN
	;;
esac

echo -e "${RETURNSTRING} | ${PERFSTRING}"
exit $STATE
