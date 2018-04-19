# ils-aux-reports

Here are some examples of automated reports on the Sierra ILS database.

In the first example script ```claims_returned```, the automation has 
been implemented using Python, which is probably the most logical 
choice in terms of languages to use for this application. Getting it up 
and running is fairly easy, and is explained in the ```readme.md``` 
file within that directory.

In the second example script, ```duplicate_patron_barcode``` the 
automation has been implemented in PHP. This method makes use of the 
PHP-CLI software, and may require additional php software packages that 
should be provided by most major distributions of Linux. This script 
makes use of a second script (written in bash) that will invoke the PHP 
interpreter as well as handle the sending of any output the PHP script 
produces via email (using mailx, a fairly standard mail application 
available on Linux platforms). It might be worth noting that this 
method is a little more complex than the Python scripts used for this 
same purpose.
