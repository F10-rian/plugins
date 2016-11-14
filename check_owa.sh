#!/bin/bash
#
# Script Info
PROGVERSION="Version 1.0"
AUTHOR="Florian Seidel"
PROGNAME="chech_owa.sh"
LAST_CHANGE="26.10.2016"

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
   -U <URL without protocol> 
   -u <Username>
   -p <Password>
   -d <domain>
   echo -e Example: $PROGNAME -U 'mail.wbs-it.de' -u 'MYUSER' -p 'MYPASS'"
}

function print_requirements {
	echo -e "required Packages:
	curl"
}

function print_help {
   # Print detailed help information
   print_rev
   print_usage
   print_requirements
}

# Parse command line options
while getopts h:U:u:p:d:* option; do
	case $option in
	h)
	print_help
	exit 0
	;;
	U)
	SERVER=$OPTARG
	;;
	u)
	USERNAME=$OPTARG
	;;
	p)
	PASSWORD=$OPTARG
	;;
	d)
	DOMAIN=$OPTARG
	;;
	*)
	print_help
	exit 3
	;;
	esac
done

SUCCESSSTRING="Mit Microsoft Exchange verbunden"

function owa_access(){
	TESTSTRING=`curl -s -k -q -d "destination=https://${SERVER}/owa&flags=0&username=${USERNAME}&password=${PASSWORD}&isutf8=1" https://${SERVER}/owa/auth/owaauth.dll -L -b /tmp/wbs_owa_cookies.txt | grep "${SUCCESSSTRING}"`

	if [[ $TESTSTRING == *"${SUCCESSSTRING}"* ]]; then
		RETURNSTRING="OK: Exchange login successful"
		STATE=$STATE_OK
	else
		RETURNSTRING="CRITICAL: Exchange login failure"
		STATE=$STATE_CRITICAL
	fi


#	if [ -n "$TESTSTRING" ]; then
	
#	curl -skIf -u '${USERNAME}@${DOMAIN}:${PASSWORD}' "${URL}" >/dev/null 2>&1
#	if [ $? != 0 ]; then
#		RETURNSTRING="CRITICAL: Exchange login failure"
#		STATE=$STATE_CRITICAL
#	else
#		RETURNSTRING="OK: Exchange login successful"
#	        STATE=$STATE_OK
#	fi
#RETURNSTRING=$TESTSTRING
}

owa_access

# echo "curl -skIf -u '${USERNAME}@${DOMAIN}:${PASSWORD}' "${URL}" >/dev/null 2>&1"
# echo $STATE
#echo "SUCCESSSTRING: ${SUCCESSSTRING}"
#echo "TESTSTRING:    ${TESTSTRING}"
echo -e "${RETURNSTRING} | ${PERFSTRING}"
exit $STATE
