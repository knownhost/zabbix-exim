#!/bin/bash

# Set Variables
EXIMLOG=/var/log/exim_mainlog
MYLOG=/tmp/exim_status.log
OFFSETFILE=/tmp/eximstatusoffset.dat
EXIMSTATS=/usr/sbin/eximstats
LOGTAIL=/usr/sbin/logtail
ZABBIX_SENDER=/usr/bin/zabbix_sender
ZABBIX_CONF=/etc/zabbix/zabbix_agentd.conf
TMP1=$(mktemp)
TMP2=$(mktemp)

if [[ $1 ]]
then
  EXIMLOG=$1
fi

function zsend {
  echo "$1 $2"
  $ZABBIX_SENDER -c $ZABBIX_CONF -k $1 -o $2
}

$LOGTAIL -f $EXIMLOG -o $OFFSETFILE > $TMP1
$EXIMSTATS -t0 -nvr $TMP1 > $TMP2

echo "Errors 0 0" >> $TMP2

zsend exreceived `grep -m 1 Received $TMP2|awk '{if (!NR) print 0; else print $3}'`
zsend exdelivered `grep -m 1 Delivered $TMP2|awk '{if (!NR) print 0; else print $3}'`
zsend exerrors `grep -m 1 Errors $TMP2|awk '{if (!NR) print 0; else print $3}'`
zsend exbytesreceived `grep -m 1 "Received" $TMP2|awk '{if (!NR) print 0; else print $2}'`
zsend exbytesdelivered `grep -m 1 "Delivered" $TMP2|awk '{if (!NR) print 0; else print $2}'`
zsend exoutbound `sed -e '/Deliveries by transport/,/Messages received per hour/!d' $TMP2 |grep remote_smtp |awk '{sum += $3} END {if (!NR) print 0; else print sum}'`
zsend exinbound `sed -e '/Deliveries by transport/,/Messages received per hour/!d' $TMP2 |grep -E "(dovecot|cagefs_virtual_address_pipe)" |awk '{sum += $3} END {if (!NR) print 0; else print sum}'`
zsend exmailqueue `exim -bpc`

rm $TMP1
rm $TMP2
