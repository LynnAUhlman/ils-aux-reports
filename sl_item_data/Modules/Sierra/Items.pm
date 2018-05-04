package Sierra::Items;

use 5.008007;
use warnings;
use strict;
use Carp;
use DBI;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    itype_names_hash
    lowest_item_row_id
    highest_item_row_id
);
our @EXPORT = ();

sub itype_names_hash
{
	#------------------------------------------------------------------------------------------------------------------------
	# DB Query
	 
	my $db_host = 'sierra-db.plch.net';  #TODO: don't hard code this
	#my $db_host = 'sierra-train.cincinnatilibrary.org';
	my $db_port = '1032';
	my $db_user = 'sqlaccess';
	my $db_pass = 'sql123';

	#print " + We're connecting to ".$db_host." for SQL query...\n";
	my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>1});

	my $sql_query 	 = "SELECT ";
		$sql_query .= "  itype_property.code_num, ";
		$sql_query .= "  itype_property_name.name ";
		$sql_query .= "FROM ";
		$sql_query .= "sierra_view.itype_property, ";
		$sql_query .= "sierra_view.itype_property_name " ;
		$sql_query .= "WHERE ";
		$sql_query .= "itype_property_name.itype_property_id = itype_property.id ";

		$sql_query .= ";";

	my $sth = $dbh->prepare($sql_query);

	#print $sql_query."\n\n";

	$sth->execute();
	#------------------------------------------------------------------------------------------------------------------------
	my %name_for_code;

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		my $code = 	( defined $item_info->{'code_num'} ) ? $item_info->{'code_num'} : '';
		my $name = 	( defined $item_info->{'name'} ) ? $item_info->{'name'} : '';
		
		$name_for_code{$code} = $name;
	}
	#------------------------------------------------------------------------------------------------------------------------
	
	return %name_for_code;
}

sub lowest_item_row_id
{
	#------------------------------------------------------------------------------------------------------------------------
	# DB Query
	 
	my $db_host = 'sierra-db.plch.net';  #TODO: don't hard code this
	#my $db_host = 'sierra-train.cincinnatilibrary.org';
	my $db_port = '1032';
	my $db_user = 'sqlaccess';
	my $db_pass = 'sql123';

	#print " + We're connecting to ".$db_host." for SQL query...\n";
	my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>1});

	my $sql_query 	 = "SELECT MIN(id) FROM sierra_view.item_view ;";

	my $sth = $dbh->prepare($sql_query);

	#print $sql_query."\n\n";

	$sth->execute();
	#------------------------------------------------------------------------------------------------------------------------
	my $id;

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		$id = 	( defined $item_info->{'min'} ) ? $item_info->{'min'} : '0';
	}
	#------------------------------------------------------------------------------------------------------------------------
	
	return $id;
}

sub highest_item_row_id
{
	#TODO: consider combining the lowest and highets subroutines into one?

	#------------------------------------------------------------------------------------------------------------------------
	# DB Query
	 
	my $db_host = 'sierra-db.plch.net';  #TODO: don't hard code this
	#my $db_host = 'sierra-train.cincinnatilibrary.org';
	my $db_port = '1032';
	my $db_user = 'sqlaccess';
	my $db_pass = 'sql123';

	#print " + We're connecting to ".$db_host." for SQL query...\n";
	my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>1});

	my $sql_query 	 = "SELECT MAX(id) FROM sierra_view.item_view ;";

	my $sth = $dbh->prepare($sql_query);

	#print $sql_query."\n\n";

	$sth->execute();
	#------------------------------------------------------------------------------------------------------------------------
	my $id;

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		$id = 	( defined $item_info->{'max'} ) ? $item_info->{'max'} : '0';
	}
	#------------------------------------------------------------------------------------------------------------------------
	
	return $id;
}


1;
