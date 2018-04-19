<?php
/*
* Ray Voelker
* PLCH 
* last updated: 2017-06-30
* 
* Finds barcodes that appear on multiple patron recods and produces a 
* list of those patrons
* 
*/

/*
include file (duplicate_patron_barcode.cfg.php) supplies the following
arguments as the example below illustrates :
	$username = "username";
	$password = "password";
	$dsn = "pgsql:"
		. "host=sierra-db.school.edu;"
		. "dbname=iii;"
		. "port=1032;"
		. "sslmode=require;";
*/
//reset all variables needed for our connection
$username = null;
$password = null;
$dsn = null;
$connection = null;
require_once('./duplicate_patron_barcode.cfg');
//make our database connection
try {
	$connection = new PDO($dsn, $username, $password);
}
catch ( PDOException $e ) {
	$row = null;
	$statement = null;
	$connection = null;
	echo "problem connecting to database...\n";
	error_log('PDO Exception: '.$e->getMessage());
	exit(1);
}
//set output to utf-8
$connection->query('SET NAMES UNICODE');
$sql = '
SELECT
r.creation_date_gmt as created_date,
e.index_entry as barcode,
\'p\' || r.record_num || \'a\' as patron_record_num,
n.last_name || \', \' ||n.first_name || COALESCE(\' \' || NULLIF(n.middle_name, \'\'), \'\') || \' \' || p.birth_date_gmt as patron,
p.ptype_code as ptype,
p.activity_gmt as last_circ_activity,
p.expiration_date_gmt as expiration_date

FROM
sierra_view.phrase_entry as e

JOIN
sierra_view.patron_record as p
ON
  p.record_id = e.record_id

JOIN
sierra_view.record_metadata as r
ON
  r.id = p.record_id

JOIN
sierra_view.patron_record_fullname AS n
ON
  n.patron_record_id = r.id

WHERE 
e.index_tag || e.index_entry IN (

	SELECT
	\'b\' || e.index_entry as barcode

	FROM
	sierra_view.phrase_entry AS e

	JOIN
	sierra_view.patron_record as p
	ON
	  p.record_id = e.record_id

	WHERE
	e.index_tag || e.varfield_type_code = \'bb\'

	GROUP BY
	barcode

	HAVING 
	count(*) > 1
)

ORDER BY
barcode,
patron ASC';


$statement = $connection->prepare($sql);
$statement->execute();
$row = $statement->fetchAll(PDO::FETCH_ASSOC);

// header('Access-Control-Allow-Origin: *');
// header('Content-Type: application/json; charset=utf8');
// echo json_encode($row);

// if there were results, create a new file
if (count($row) > 0) {
	// create output file
	$filename='duplicate_patron_barcode-' . date('Y-m-d') . '.csv';
	$fp = fopen($filename, 'w');

	// make UTF-8 File for Excel
	fputs($fp, $bom =( chr(0xEF) . chr(0xBB) . chr(0xBF) ));

	// put the array keys as the first row of the csv file
	fputcsv($fp, array_keys($row[0]));

	foreach ($row as $line) {
		fputcsv($fp, $line);
	}
	fclose($fp);
}

$fp = null;
$row = null;
$statement = null;
$connection = null;
?>
