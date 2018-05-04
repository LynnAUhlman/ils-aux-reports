#!/usr/bin/python3

import sys
import csv
import xlsxwriter
import os
import datetime

#~ the file should exist at the current path + /output ...
file_item_not_circ_or_checked_out = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-item_not_circ_or_checked_out.csv")
file_item_on_shelf = os.getcwd() + datetime.date.today().strftime("/output/%Y-%m-%d-file_item_on_shelf.csv")

print(file_item_not_circ_or_checked_out)
print(file_item_on_shelf)

if ( not os.path.isfile(file_item_not_circ_or_checked_out) and not os.path.isfile(file_item_on_shelf) ):
	print('exiting...')
	sys.exit(0)

print('we do the next part') 
