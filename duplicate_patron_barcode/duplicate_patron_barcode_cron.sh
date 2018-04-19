#!/bin/bash

cd /home/plchuser/reports/duplicate_patron_barcode/
/usr/bin/php /home/plchuser/reports/duplicate_patron_barcode/duplicate_patron_barcode.php &
wait

if [ -e /home/plchuser/reports/duplicate_patron_barcode/duplicate_patron_barcode-`date +%Y-%m-%d`.csv ] 
then 
	#debug
	#echo "file exists!"

	# send the message with the attachment to the distribution list: duplicate_patron_barcode
	#  defined in the /etc/aliases file
	mailx -r reports@ilsauxrh6.plch.net \
	-s "duplicate_patron_barcode report" \
	-a /home/plchuser/reports/duplicate_patron_barcode/duplicate_patron_barcode-`date +%Y-%m-%d`.csv \
	duplicate_patron_barcode \
	< /dev/null

fi
