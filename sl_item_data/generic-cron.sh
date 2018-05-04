#!/bin/bash

TODAY=`date +%Y%m%d`
TODAYHYPHENS=`date +%Y-%m-%d`
WEEKAGO=`date -d '7 days ago' +%Y%m%d`
TWOWEEKSAGO=`date -d '14 days ago' +%Y%m%d`
MONTHAGO=`date -d '30 days ago' +%Y%m%d`
YEARAGO=`date -d '365 days ago' +%Y%m%d`


STARTTIMESTAMP=`date +%Y%m%d%H%M%S`
STARTEPOCH=`date +%s`


# SET VARIABLES TO DEFAULTS IF NOT SET BY CALLING SCRIPT

if [[ -z "$REPORTNAME" ]]
then
	FULLNAME="Generic Report"
	REPORTNAME=generic
	SOURCEFILE=SierraGenericReport.pl
fi

if [[ -z "$LOGFILE" ]]
then
  LOGFILE=$REPORTNAME-log
fi

if [[ -z "$JSONFILE" ]]
then
  JSONFILE=$REPORTNAME
fi

if [[ -z "$KEEPPERIOD" ]]
then
  KEEPPERIOD="YEAR"
fi

if [[ -z "$LINK" ]]
then
  LINK="nil"
fi


# RUN THE REPORT

echo "Start."
date

cd /home/plchuser/Reports/$REPORTNAME/

perl ./$SOURCEFILE >> $LOGFILE-$TODAY.txt

date

FINISHTIMESTAMP=`date +%Y%m%d%H%M%S`
FINISHEPOCH=`date +%s`


# CREATE END REPORT JSON FILE

echo "{ \"fullName\": \"$FULLNAME\", \
        \"name\": \"$REPORTNAME\", \
        \"date\": \"$TODAYHYPHENS\", \
        \"timeStarted\": \"$STARTEPOCH\", \
        \"timeFinished\": \"$FINISHEPOCH\", \
        \"logFile\": \"$LOGFILE-$TODAY.txt\", \
        \"link\": \"$LINK\" \
      }" > $STARTTIMESTAMP-$JSONFILE.json

date


# CLEANUP LOCAL LOG FILES ETC

echo "KEEPPERIOD is $KEEPPERIOD..."

if [ "$KEEPPERIOD" == "YEAR" ]
then
  if [ -f $REPORTNAME-log-$YEARAGO.txt ]
  then
    rm $REPORTNAME-log-$YEARAGO.txt
  fi
    find . -type f -name '*-*.json' -mtime +366 -print | xargs -r echo
    find . -type f -name '*-*.json' -mtime +366 -print | xargs -r rm
    find . -type f -name '*-log-*.txt' -mtime +366 -print | xargs -r echo
    find . -type f -name '*-log-*.txt' -mtime +366 -print | xargs -r rm
fi

if [ "$KEEPPERIOD" == "MONTH" ]
then
  if [ -f $REPORTNAME-log-$MONTHAGO.txt ]
  then
    rm $REPORTNAME-log-$MONTHAGO.txt
  fi
  find . -type f -name '*-*.json' -mtime +32 -print | xargs -r echo
  find . -type f -name '*-*.json' -mtime +32 -print | xargs -r rm
  find . -type f -name '*-log-*.txt' -mtime +32 -print | xargs -r echo
  find . -type f -name '*-log-*.txt' -mtime +32 -print | xargs -r rm
fi

if [ "$KEEPPERIOD" == "WEEK" ]
then
  if [ -f $REPORTNAME-log-$WEEKAGO.txt ]
  then
    rm $REPORTNAME-log-$WEEKAGO.txt
  fi
  find . -type f -name '*-*.json' -mtime +8 -print | xargs -r echo
  find . -type f -name '*-*.json' -mtime +8 -print | xargs -r rm
  find . -type f -name '*-log-*.txt' -mtime +8 -print | xargs -r echo
  find . -type f -name '*-log-*.txt' -mtime +8 -print | xargs -r rm
fi

# FTP FILES TO main12 AND DELETE OLD REMOTE FILES
#echo "starting FTP"
#ftp -inv main12.plch.net << EOF

#user anonymous plchuser@ilsaux.plch.net

#binary

#cd /sierra/logs

#put $LOGFILE-$TODAY.txt
#put $STARTTIMESTAMP-$JSONFILE.json

#delete $LOGFILE-$WEEKAGO.txt

#mdelete $WEEKAGO*-$JSONFILE.json

#bye
#EOF
#echo "FTP done."

echo "moving files to MESA"
# CP FILES TO MESA
cp $STARTTIMESTAMP-$JSONFILE.json /var/www/html/mesa/finished
cp $LOGFILE-$TODAY.txt /var/www/html/mesa/logs

echo "removing old MESA files..."
find /var/www/html/mesa/finished -type f -name '*-*.json' -mtime +32 -print | xargs -r -n 1 echo
find /var/www/html/mesa/finished -type f -name '*-*.json' -mtime +32 -print | xargs -r -n 1 rm
find /var/www/html/mesa/logs -type f -name '*-log-*.txt'  -mtime +32 -print | xargs -r -n 1 echo
find /var/www/html/mesa/logs -type f -name '*-log-*.txt'  -mtime +32 -print | xargs -r -n 1 rm

echo "indexing MESA files..."
# INDEX FILES FOR MESA
/home/plchuser/bin/json-wn.pl > /var/www/html/mesa/upcoming.json
/home/plchuser/bin/json-index.pl > /var/www/html/mesa/finished/index.json

date

echo "Done."
