#!/bin/bash
#
# Script Info
PROGVERSION="Version 1.2"
AUTHOR="Florian Seidel"
PROGNAME="chech_ups.sh"
LAST_CHANGE="17.01.2017"

# Changlog
# Version 1.2
# add GENEREX managed UPS Monitoring
#
# Version 1.1
# add APC managed UPS Monitoring

# OIDs
#
# HP battery_time_remaining .1.3.6.1.4.1.232.165.3.2.1.0 (sec)
# HP battery_voltage			.1.3.6.1.4.1.232.165.3.2.2.0
# HP battery_capacity			.1.3.6.1.4.1.232.165.3.2.4.0
# HP battery_current .1.3.6.1.4.1.232.165.3.2.3.0
#APC battery_current .1.3.6.1.4.1.318.1.1.1.4.2.4.0
#APC battery_capacity .1.3.6.1.4.1.318.1.1.1.2.2.1.0
#APC battery_voltage .1.3.6.1.4.1.318.1.1.1.3.2.1.0
#APC battery_time_remaining  .1.3.6.1.4.1.318.1.1.1.2.2.3.0 (Timeticks -> snmpwalk -v 1 -c public 10.22.254.206 .1.3.6.1.4.1.318.1.1.1.2.2.3.0 -O v | awk '{print $2}' | sed 's/.//;s/.$//')
#GENEREX battery_time_remaining .1.3.6.1.2.1.33.1.2.3.0 (minutes)
#GENEREX battery_voltage .1.3.6.1.2.1.33.1.2.5.0 (0.1 Volt DC)
#GENEREX battery_current .1.3.6.1.2.1.33.1.2.6.0 (0.1 Amp DC)
#GENEREX battery_capacity .1.3.6.1.2.1.33.1.2.4.0
#GENEREX temperature .1.3.6.1.2.1.33.1.2.7.0 (degrees Centigrade)


# Variables

# Nagios/Icinga API Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
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
   -H <UPS>
   -D <UPS Devicetype HP or APC>
   -v <SNMP Version 1 or 2c>
   -C <Community String>
   -M <Mode>
		battery_time_remaining
		battery_capacity
		temperature (GENEREX only)
   -u <unit>
   -w <Warning max Value in %,sec,min,hour>
   -c <Critical max Value in %>"
   echo -e "Example: $PROGNAME -H 192.168.13.13 -v 2c -C public -D GENEREX -M battery_capacity -w 90 -c 80"
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

function battery_time_remaining(){
	case $DEVICETYPE in
		HP)
			BATTERY_TIME_REMAINING_SEC=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.232.165.3.2.1.0 -O q -O v`
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.232.165.3.2.4.0 -O q -O v`
		;;
		APC)
			TIMETICKS=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.318.1.1.1.2.2.3.0 -O v | awk '{print $2}' | sed 's/.//;s/.$//'`
			BATTERY_TIME_REMAINING_SEC=$(echo "${TIMETICKS}/100" | bc)
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.318.1.1.1.2.2.1.0 -O q -O v`
		;;
		GENEREX)
			BATTERY_TIME_REMAINING_MIN=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.2.1.33.1.2.3.0 -O q -O v`
			BATTERY_TIME_REMAINING_SEC=$(echo ${BATTERY_TIME_REMAINING_MIN}*60 | bc)
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.2.1.33.1.2.4.0 -O q -O v`		
		;;
		*)
			echo "device is not supported"
			print_help
			exit $STATE_UNKNOWN
		;;
	esac
	
	if [ $CRITICAL -ge $WARNING ]
			then
				echo "warning value must be larger than critical"
				print_help
				exit $STATE_UNKNOWN
			fi
			
			case $UNIT in
				%)
					RETURNSTRING="Stupid idea getting a time as percentage"
					exit $STATE_UNKNOWN
				;;
				sec)
					BATTERY_TIME_REMAINING_SEC_MAX=$(echo "(${BATTERY_TIME_REMAINING_SEC}*100)/${BATTERY_CAPACITY}" | bc)
					
					if [  $WARNING -le $BATTERY_TIME_REMAINING_SEC ]
					then
						STATE=$STATE_OK
					elif [ $CRITICAL -gt $BATTERY_TIME_REMAINING_SEC ]
					then
						STATE=$STATE_CRITICAL
					elif [ $WARNING -gt $BATTERY_TIME_REMAINING_SEC ]
					then
						STATE=$STATE_WARNING
					else
						STATE=$STATE_UNKNOWN
					fi
					RETURNSTRING="Battery Time Remaining: ${BATTERY_TIME_REMAINING_SEC}sec"
					PERFSTRING="'Battery_Time_Remaining'=${BATTERY_TIME_REMAINING_SEC}sec;$WARNING;$CRITICAL;0;${BATTERY_TIME_REMAINING_SEC_MAX}"
				;;
				min)
					BATTERY_TIME_REMAINING_MIN=$(echo ${BATTERY_TIME_REMAINING_SEC}/60 | bc)
					BATTERY_TIME_REMAINING_MIN_MAX=$(echo "(${BATTERY_TIME_REMAINING_MIN}*100)/${BATTERY_CAPACITY}" | bc)
					
					if [ $WARNING -le $BATTERY_TIME_REMAINING_MIN ]
					then
						STATE=$STATE_OK
					elif [ $CRITICAL -gt $BATTERY_TIME_REMAINING_MIN ]
					then
						STATE=$STATE_CRITICAL
					elif [ $WARNING -gt $BATTERY_TIME_REMAINING_MIN ]
					then
						STATE=$STATE_WARNING
					else
						STATE=$STATE_UNKNOWN
					fi
					RETURNSTRING="Battery Time Remaining: ${BATTERY_TIME_REMAINING_MIN}min"
					PERFSTRING="'Battery_Time_Remaining'=${BATTERY_TIME_REMAINING_MIN}min;$WARNING;$CRITICAL;0;${BATTERY_TIME_REMAINING_MIN_MAX}"
				;;
				hour)
					BATTERY_TIME_REMAINING_H=$(echo ${BATTERY_TIME_REMAINING_SEC}/3600 | bc)
					BATTERY_TIME_REMAINING_H_MAX=$(echo "(${BATTERY_TIME_REMAINING_H}*100)/${BATTERY_CAPACITY}" | bc)
					
					if [ $WARNING -le $BATTERY_TIME_REMAINING_H ]
					then
						STATE=$STATE_OK
					elif [ $CRITICAL -gt $BATTERY_TIME_REMAINING_H ]
					then
						STATE=$STATE_CRITICAL
					elif [ $WARNING -gt $BATTERY_TIME_REMAINING_H ]
					then
						STATE=$STATE_WARNING
					else
						STATE=$STATE_UNKNOWN
					fi
					RETURNSTRING="Battery Time Remaining: ${BATTERY_TIME_REMAINING_H}hour"
					PERFSTRING="'Battery Time Remaining'=${BATTERY_TIME_REMAINING_H}hour;$WARNING;$CRITICAL;0;${BATTERY_TIME_REMAINING_H_MAX}"
				;;
				*)
					echo "wrong or no unit"
					print_usage
					exit $STATE_UNKNOWN
				;;
			esac
}

function battery_voltage(){
	case $DEVICETYPE in
		HP)
			BATTERY_VOLTAGE=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.232.165.3.2.2.0 -O q -O v`
		;;
		APC)
			BATTERY_VOLTAGE=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.318.1.1.1.3.2.1.0 -O q -O v`
		;;
		GENEREX)
			BATTERY_VOLTAGE_TENTH=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.2.1.33.1.2.5.0 -O q -O v`
			BATTERY_VOLTAGE=$(echo ${BATTERY_VOLTAGE_TENTH}*10 | bc)
		;;
		*)
			echo "device is not supported"
			print_help
			exit $STATE_UNKNOWN
		;;
	esac
	UNIT="Volt"
	if [ $CRITICAL -ge $WARNING ]
	then
		echo "warning value must be larger than critical"
		print_help
		exit $STATE_UNKNOWN
	fi
	echo "${BATTERY_VOLTAGE} ${UNIT}"
	if [ $WARNING -le $BATTERY_VOLTAGE ]
	then
		STATE=$STATE_OK
	elif [ $CRITICAL -gt $BATTERY_VOLTAGE ]
	then
		STATE=$STATE_CRITICAL
	elif [ $WARNING -gt $BATTERY_VOLTAGE ]
	then
		STATE=$STATE_WARNING
	else
		STATE=$STATE_UNKNOWN
	fi
	RETURNSTRING="Battery Voltage: ${BATTERY_VOLTAGE}Volt"
	PERFSTRING="'Battery Voltage'=${BATTERY_VOLTAGE}${UNIT};$WARNING;$CRITICAL;0;500"
}

function battery_capacity(){
	case $DEVICETYPE in
		HP)
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.232.165.3.2.4.0 -O q -O v`
		;;
		APC)
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.4.1.318.1.1.1.2.2.1.0 -O q -O v`
		;;
		GENEREX)
			BATTERY_CAPACITY=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.2.1.33.1.2.4.0 -O q -O v`	
		;;
		*)
			echo "device is not supported"
			print_help
			exit $STATE_UNKNOWN
	esac
	UNIT="%"
	if [ $CRITICAL -ge $WARNING ]
	then
		echo "warning value must be larger than critical"
		print_help
		exit $STATE_UNKNOWN
	fi
	
	if [ $BATTERY_CAPACITY -gt $WARNING ]
	then
		STATE=$STATE_OK
	elif [ $BATTERY_CAPACITY -le $CRITICAL ]
	then
		STATE=$STATE_CRITICAL
	elif [ $BATTERY_CAPACITY -le $WARNING ]
	then
		STATE=$STATE_WARNING
	else
		STATE=$STATE_UNKNOWN
	fi
	RETURNSTRING="Battery Capacity: ${BATTERY_CAPACITY}%"
	PERFSTRING="'Battery Capacity'=${BATTERY_CAPACITY}%;$WARNING;$CRITICAL;0;100"
}

function temperature(){
	case $DEVICETYPE in
		GENEREX)
			TEMPERATUR_CELCIUS=`snmpwalk -v $VERSION -c $COMMUNITY $IP .1.3.6.1.2.1.33.1.2.7.0 -O q -O v`	
		;;
		*)
			echo "device is not supported"
			print_help
			exit $STATE_UNKNOWN
	esac
	UNIT="°C"
	if [ $WARNING -ge $CRITICAL ]
	then
		echo "critical value must be larger than warning"
		print_help
		exit $STATE_UNKNOWN
	fi
	
	if [ $TEMPERATUR_CELCIUS -lt $WARNING ]
	then
		STATE=$STATE_OK
	elif [ $TEMPERATUR_CELCIUS -ge $CRITICAL ]
	then
		STATE=$STATE_CRITICAL
	elif [ $TEMPERATUR_CELCIUS -ge $WARNING ]
	then
		STATE=$STATE_WARNING
	else
		STATE=$STATE_UNKNOWN
	fi
	RETURNSTRING="Temperature: ${TEMPERATUR_CELCIUS}${UNIT}"
	PERFSTRING="'Temperature'=${TEMPERATUR_CELCIUS}${UNIT};$WARNING;$CRITICAL;0;100"
}

case $MODE in
	battery_time_remaining) battery_time_remaining
	;;
	battery_voltage) battery_voltage
	;;
	battery_capacity) battery_capacity
	;;
	temperature) temperature
	;;
esac
# echo $STATE
echo -e "${RETURNSTRING} | ${PERFSTRING}"
exit $STATE
