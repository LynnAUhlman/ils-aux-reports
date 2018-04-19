# Claims Returned Report

## Running with Python
* install / run in a Python virtualenv (within this project directory) ```virtualenv env```
* activate the virtual environment: ```source env/bin/activate```
* install the python required pip packages in that virtualenv ```pip install -r requirements.txt```
* deactivate the virtual environment: ```deactivate```
* configure crontab to run the script from the virtualenv 
```$ crontab -e```
```
# claims returned reports
# 12AM every 1st of the month
0 0 1 * *	cd /home/plchuser/ils-aux-reports/claims_returned; env/bin/python claims_returned.py
```
