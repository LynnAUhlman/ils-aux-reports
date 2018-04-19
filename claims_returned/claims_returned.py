#!/usr/bin/python3

# Ray Voelker
# ray.voelker@cincinnatilibrary.org
# ray.voelker@gmail.com

# Python script to produce a spreadsheet containing reports of claims
# returned data from both patron records, as well as item records

import sys
import configparser
import psycopg2
import xlsxwriter
import os
import datetime

from _send_plch_email import send_plch_email

# import configuration file containing our connection string
config = configparser.ConfigParser()
config.read('claims_returned.ini')

# close all open database connections and the main cursor
def clear_connection():
	if 'conn' in globals():
		global conn
		if hasattr(conn, 'close'):
			conn.close()
		conn = None
	
	if 'cur' in globals():
		global cur
		if hasattr(cur, 'close'):
			cur.close()
		cur = None

try:
	# variable connection string should be defined in the imported config file
	conn = psycopg2.connect( config['db']['connection_string'] )
except:
	print("unable to connect to the database")
	clear_connection()
	sys.exit(1)

# sql statement (in the heredoc type style)
sql = """\
DROP TABLE IF EXISTS temp_claims_returned;
--


CREATE TEMP TABLE temp_claims_returned AS
SELECT
r.record_type_code,
r.record_type_code || r.record_num || 'a' as record_num,
(
	SELECT
	string_agg(v.field_content, ',' order by v.occ_num)

	FROM
	sierra_view.varfield as v

	WHERE
	v.record_id = r.id
	AND v.varfield_type_code = 'b'
) AS item_barcodes,
substring(v.field_content, '^.{15}')::date as claimed_date,
v.record_id,
v.field_content

FROM
sierra_view.varfield as v

JOIN
sierra_view.record_metadata as r
ON
  (r.id = v.record_id)

WHERE
v.varfield_type_code = 'x'
AND v.marc_tag is null
AND v.field_content ~ '^.{17}Claimed returned'
AND r.record_type_code ~* 'i|p'
;
---
"""

# create a new cursor and execute
try:
	cur = conn.cursor()
	cur.execute(sql)
	
except:
	print("error connecting or running query sql")
	clear_connection()
	sys.exit(1)


# first query successful, so create our excel file...

#~ check if the output directory exists ... if not, create it
if not os.path.exists( os.getcwd() + '/output' ):
	print("directory doesn't exist! ... creating it")
	os.makedirs(os.getcwd() + '/output')

file_wb = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-claims_returned_sol.xlsx")
wb = xlsxwriter.Workbook(file_wb)
ws1 = wb.add_worksheet("claims_returned_by_item")
ws2 = wb.add_worksheet("claims_returned_by_patron")

print("ITEM CLAIMS RETURNED DATA\n\n")

sql_item = """
-- produce our results for items
SELECT
c.record_type_code, -- 0 string 
c.record_num, -- 1 string
c.item_barcodes, -- 2 string
c.claimed_date, -- 3 string
c.field_content -- 4 string

FROM
temp_claims_returned as c

WHERE
( date_trunc('month', NOW()::timestamp) - INTERVAL '5 years' )::timestamp > c.claimed_date::timestamp -- 5 years from first date in month is greater than the claimed returend date
AND c.record_type_code = 'i'

ORDER BY
claimed_date
;
---
"""

try:
	cur.execute(sql_item)
	
except:
	print("error connecting or running query sql_item")
	clear_connection()
	sys.exit(1)


#output results to excel sheet

#set the column names ...
ws1.write_string(0, 0, str('record_num') )
ws1.write_string(0, 1, str('item_barcodes') )
ws1.write_string(0, 2, str('claimed_date') )
ws1.write_string(0, 3, str('varfield_content') )

row_counter = 1

for record in cur:
	ws1.write_string(row_counter, 0, str(record[1]) ) # c.record_num, -- 1 string
	ws1.write_string(row_counter, 1, str(record[2]) ) # c.item_barcodes, -- 2 string
	ws1.write_string(row_counter, 2, str(record[3]) ) # c.claimed_date, -- 3 string
	ws1.write_string(row_counter, 3, str(record[4]) ) # c.field_content -- 4 string
	
	row_counter += 1

# set the columns to the correct width
ws1.set_column('A:A', 10)
ws1.set_column('B:B', 14)
ws1.set_column('C:C', 11)
ws1.set_column('D:D', 60)

# Freeze the first row.
ws1.freeze_panes(1, 0)  

# ---

print("PATRON CLAIMS RETURNED DATA\n\n")

sql_patron = """
-- produce our results for items
SELECT
c.record_type_code, -- 0 string 
c.record_num, -- 1 string
c.item_barcodes, -- 2 string
c.claimed_date, -- 3 string
c.field_content -- 4 string

FROM
temp_claims_returned as c

WHERE
( date_trunc('month', NOW()::timestamp) - INTERVAL '5 years' )::timestamp > c.claimed_date::timestamp -- 5 years from todays date is greater than the claimed returend date
AND c.record_type_code = 'p'

ORDER BY
claimed_date
;
---
"""

try:
	cur.execute(sql_patron)
	
except:
	print("error connecting or running query sql_patron")
	clear_connection()
	sys.exit(1)


#output results to excel sheet

#set the column names ...
ws2.write_string(0, 0, str('record_num') )
ws2.write_string(0, 1, str('item_barcodes') )
ws2.write_string(0, 2, str('claimed_date') )
ws2.write_string(0, 3, str('varfield_content') )

row_counter = 1

for record in cur:
	ws2.write_string(row_counter, 0, str(record[1]) ) # c.record_num, -- 1 string
	ws2.write_string(row_counter, 1, str(record[2]) ) # c.item_barcodes, -- 2 string
	ws2.write_string(row_counter, 2, str(record[3]) ) # c.claimed_date, -- 3 string
	ws2.write_string(row_counter, 3, str(record[4]) ) # c.field_content -- 4 string
	
	row_counter += 1

# set the columns to the correct width
ws2.set_column('A:A', 10)
ws2.set_column('B:B', 14)
ws2.set_column('C:C', 11)
ws2.set_column('D:D', 60)

# Freeze the first row.
ws2.freeze_panes(1, 0)

# finishing up ... 
clear_connection()
wb.close()

# email the file to the approriate people (defined in the config)
# change the email body here, otherwise, pull it from the config
email_body = config['email']['email_body']

send_plch_email(config['email']['email_from'], config['email']['email_list'].split(), config['email']['email_subject'], email_body, [file_wb])

print("done!\n\n")
