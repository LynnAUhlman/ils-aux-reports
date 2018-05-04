#!/bin/bash

cd /home/plchuser/ils-aux-reports/item_level_holds

touch output/temp.file

/usr/bin/php item_level_holds.php

/usr/bin/python3 item_level_holds_convert.py

cd output

rm item_level_holds.zip

find * -newer temp.file -print | zip "item_level_holds.zip" -@

OUTPUT="$(find *.csv -newer temp.file -print | xargs wc -l)"

echo -e "item level holds\n${OUTPUT}" | mutt -s "item level holds report" item_level_holds_mail -a "item_level_holds.zip"
