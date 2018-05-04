#!/usr/bin/python3

import sys
import csv
import xlsxwriter
import os
import datetime

# if we read f.csv we will write f.xlsx
#wb = xlsxwriter.Workbook(sys.argv[1].replace(".csv",".xlsx"))

file_wb = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-item_level_holds.xlsx")
wb = xlsxwriter.Workbook(file_wb)
ws1 = wb.add_worksheet("item_not_circ_or_checked_out")
ws2 = wb.add_worksheet("item_on_shelf")

#~ the file should exist at the current path + /output ...
file_item_not_circ_or_checked_out = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-item_not_circ_or_checked_out.csv")
file_item_on_shelf = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-item_on_shelf.csv")

#~ if the files don't exist, exit
if ( not os.path.isfile(file_item_not_circ_or_checked_out) and not os.path.isfile(file_item_on_shelf) ):
	print('exiting...')
	sys.exit(0)

with open(file_item_not_circ_or_checked_out, 'r') as csvfile:
	table = csv.reader(csvfile)
	i = 0
	# write each row from the csv file as text into the excel file
	# this may be adjusted to use 'excel types' explicitly (see xlsxwriter doc)
	for row in table:
		ws1.write_row(i, 0, row)
		i += 1

with open(file_item_on_shelf, 'r') as csvfile:
	table = csv.reader(csvfile)
	i = 0
	# write each row from the csv file as text into the excel file
	# this may be adjusted to use 'excel types' explicitly (see xlsxwriter doc)
	for row in table:
		ws2.write_row(i, 0, row)
		i += 1

#set the column widths
ws1.set_column('A:A', 16)
ws2.set_column('A:A', 16)

ws1.set_column('B:B', 15)
ws2.set_column('B:B', 15)

ws1.set_column('C:C', 8)
ws2.set_column('C:C', 8)

ws1.set_column('D:D', 12)
ws2.set_column('D:D', 12)

ws1.set_column('E:E', 8)
ws2.set_column('E:E', 8)

ws1.set_column('F:F', 12)
ws2.set_column('F:F', 12)

ws1.set_column('I:I', 12)
ws2.set_column('I:I', 12)

ws1.set_column('K:K', 12)
ws2.set_column('K:K', 12)
		
wb.close()
