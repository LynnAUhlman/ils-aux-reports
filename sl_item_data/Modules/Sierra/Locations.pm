package Sierra::Locations;

use 5.008007;
use warnings;
use strict;
use Carp;
use DBI;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    location_names_hash
	is_branch_prefix
	is_location_offsite
	is_location_virtual
	is_location_innreach
	is_location_administrative
);
our @EXPORT = ();

sub is_branch_prefix 
{
	return map { $_ => 1 } qw( an av ba bh ch cl co cr cv dp dt ep fo ge gh gr ha hp lv ma mm md mn mo mt mw nw nr ns oa pl pr re sh sb sm wh wt ww wy );
}

sub is_location_offsite
{
	return map { $_ => 1 } qw( ycml ycmus yhbsh ymhs yplay ytaft ytma ytmah );
}

sub is_location_virtual
{
	return map { $_ => 1 } qw( vibin vidow vigen viint vinew );
}

sub is_location_administrative
{
	return map { $_ => 1 } qw( 5acq 5cat 5cld 5com 5dir 5fa 5fis 5hum 5lib 5mkt 5pro 5sup );
}

sub is_location_innreach
{
	return map { $_ => 1 } qw( 9ascp 9delo 9loui 9mass 9ment 9midp 9mrpl 9rodm 9slic 9star 9wcpl 9wppl
                                                ak2ug an3bg as2ug at3ug
                                                be4tg bf1ug bw3bg  
                                                ca2ug cb3bg cc2mh cc2pl cc2tg cd3bg ce3ug cf2pl ci3ug cl3tg co4bg co4tg cp4ug cr0zz cs2ug ct3tg
                                                da3ug de1bg de4ug dm2ug 
                                                ed3tg
                                                fc2bg fi1ug fr2ug fr4ug
                                                gc1pl
                                                he1bg hi2bg ho4tg
                                                jc2ug je2tg
                                                ke2bg ke2pl ke2ug
                                                la2tg lo1bg lo2tg
                                                ma2bg ma4bg mc1mh me1bg mo3bg ms4sg mt4bg mu2bg mu3ug mu4bg mv4bg
                                                nd2bg ne2mh no1tg nw1bg
                                                ob2bg oc4bg od4bg on1ug op4bg os4ug ot4bg ou4ug ow1tg ow4ug 
                                                pc2pl pc4sg po2lc
                                                re2pl ri4tg
                                                sh4ug si3tg sl4gg sm2ug so3tg
                                                te1tg ti1ug tl1pl tl4sg to1ug
                                                ua4hs ur2bg ur3ug
                                                wa2pl wa2ug wa4tg wb3ug we4pl wl3bg wo2bg ws3ug wt2pl wt3ug
                                                xa3ug 
                                                ym2pl ys2ug );
}

sub location_names_hash
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
		$sql_query .= "  location.code, ";
		$sql_query .= "  location_name.name ";
		$sql_query .= "FROM ";
		$sql_query .= "sierra_view.location, ";
		$sql_query .= "sierra_view.location_name " ;
		$sql_query .= "WHERE ";
		$sql_query .= "location_name.location_id = location.id ";

		$sql_query .= ";";

	my $sth = $dbh->prepare($sql_query);

	#print $sql_query."\n\n";

	$sth->execute();
	#------------------------------------------------------------------------------------------------------------------------
	my %name_for_code;

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		my $code = 	( defined $item_info->{'code'} ) ? $item_info->{'code'} : '';
		my $name = 	( defined $item_info->{'name'} ) ? $item_info->{'name'} : '';
		
		$name_for_code{$code} = $name;
	}
	#------------------------------------------------------------------------------------------------------------------------
	
	return %name_for_code;
}

1;
