#!/usr/bin/perl

use 5.008007;
use warnings;
use strict;

use DBI;
use XML::Simple;
use Net::FTP;
use SQL::Beautify;

my $cfg;
my $hhmmss;

BEGIN
{

	print "++++++++++++++++++++++++++++++++++\n";
	print "Shelflist: Item Data Inconsistency Report begin";
	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	$hhmmss = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	print " at ".$hhmmss."...\n";
	print "++++++++++++++++++++++++++++++++++\n";

	use Config::Simple;
	
	$cfg = new Config::Simple('slitemdata.cfg');
	
	my $sierra_modules = $cfg->param("SierraModulesLocation");
	print " + We're using modules from: " . $sierra_modules . "\n";
	
	#usually either '/home/plchuser/Modules' or '/home/plchuser/Testing/Modules'
	push(@INC,$sierra_modules);

	print "++++++++++++++++++++++++++++++++++\n";
}


# function to repeat query until it succeeds
sub item_chunk_query
{
	my ( $sql_query , $dbh ) = @_;
	
	my $sth = $dbh->prepare($sql_query);
	
	#execute SQL query and if timeout, retry given number of times
	my $number_of_tries = 10;
	while ( $number_of_tries > 0 )
	{
		print "number of tries remaining: " . $number_of_tries . "\n";
		$sth->execute();
		if ( $sth->err )
		{
			print "err: " . $sth->err . " message: " . $sth->errstr . "\n";
			$number_of_tries -= 1;
			if ( $number_of_tries eq 0 )
			{
				#TODO: die or do something useful here
				die "ran out of SQL retries";
			}
		}
		else
		{
			print "no error.  continuing...\n";
			$number_of_tries = 0;
		}
	}#end sql query retry loop
	
	return $sth;
}


#------------------------------------------------------------------------------------------------------------------------
# Set up consistency maps

use Sierra::Locations qw( is_branch_prefix is_location_offsite is_location_virtual is_location_innreach location_names_hash is_location_administrative );
use Sierra::Items qw( itype_names_hash lowest_item_row_id highest_item_row_id );

my %is_branch_prefix = is_branch_prefix(); #comes from Locations.pm
my %location_name_for_location_code = location_names_hash(); #comes from Locations.pm
$location_name_for_location_code{'1c'} = "Main - 1st Floor - Children's Learning Ctr";  #These are a kludge added so we can look up these two letter locations as if they were real
$location_name_for_location_code{'1f'} = "Main - 1st Floor - Popular Library Stacks";
$location_name_for_location_code{'1h'} = "Main - 1st Floor - Homework Center";
$location_name_for_location_code{'1l'} = "Main - 1st Floor - Children's Learning Center Stacks";  #TODO: consider moving this list into Sierra::Items
$location_name_for_location_code{'1p'} = "Main - 1st Floor - Popular Library";
$location_name_for_location_code{'1z'} = "Main - 1st Floor - Cleanup";
$location_name_for_location_code{'2e'} = "Main - 2nd Floor - Education Stacks";
$location_name_for_location_code{'2g'} = "Main - 2nd Floor - Government Stacks";
$location_name_for_location_code{'2k'} = "Main - 2nd Floor - Teen Stacks";
$location_name_for_location_code{'2m'} = "Main - 2nd Floor - Magazines & Newspapers";
$location_name_for_location_code{'2n'} = "Main - 2nd Floor - Magazines Stacks";
$location_name_for_location_code{'2r'} = "Main - 2nd Floor - Information & Reference";
$location_name_for_location_code{'2s'} = "Main - 2nd Floor - Science Stacks";
$location_name_for_location_code{'2t'} = "Main - 2nd Floor - TeenSpot";
$location_name_for_location_code{'2x'} = "Main - 2nd Floor - Tech Center";
$location_name_for_location_code{'3a'} = "Main - 3rd Floor - Art Stacks / Cincnnati Room Secured";
$location_name_for_location_code{'3c'} = "Main - 3rd Floor - Cincinnati Room";
$location_name_for_location_code{'3d'} = "Main - 3rd Floor - Genealogy & Local History (3d)";
$location_name_for_location_code{'3e'} = "Main - 3rd Floor - Genealogy & Local History (3e)";
$location_name_for_location_code{'3g'} = "Main - 3rd Floor - Genealogy & Local History (3g)";
$location_name_for_location_code{'3h'} = "Main - 3rd Floor - History Stacks";
$location_name_for_location_code{'3l'} = "Main - 3rd Floor - Literature Stacks";
$location_name_for_location_code{'3r'} = "Main - 3rd Floor - Information & Reference";
$location_name_for_location_code{'4c'} = "Main - 4th Floor - Circulation Services";
$location_name_for_location_code{'4d'} = "Main - 4th Floor - Documents and Patents";
$location_name_for_location_code{'4v'} = "Main - 4th Floor - Virtual Information Center";
$location_name_for_location_code{'no'} = "none (no)";
$location_name_for_location_code{'zz'} = "Default";

my %is_location_offsite = is_location_offsite();  #comes from Locations.pm
my %is_location_virtual = is_location_virtual();  #comes from Locations.pm
my %is_location_innreach = is_location_innreach(); #comes from Locations.pm
my %is_location_administrative = is_location_administrative(); #comes from Locations.pm

my %itype_names_hash = itype_names_hash(); #comes from Items.pm

#audience for itype
my %itypes_for_audience = (
	'a' => 	[ qw( 0 1 10 17 18 20 21 26 30 33 37 46 60 62 65 67 70 73 77 79 82 83 90 100 101 103 104 111 120 121 122 123 124 125 126 127 130 131 132 134 135 136 137 138 139 140 141 144 145 146 147 148 149 151 152 154 155 157 158 161 163 165 ) ],
	't' => 	[ qw( 4 5 12 22 23 24 32 35 46 60 72 92 134 136 143 ) ],
	'j' => 	[ qw( 2 3 11 15 16 17 18 22 23 27 31 34 61 66 71 78 79 82 91 100 101 132 134 136 139 142 146 159 160 162 163 ) ],
	);
my %is_audience_for_itype;
for my $audience (keys %itypes_for_audience){
	for my $itype ( @{$itypes_for_audience{$audience}} ){
		$is_audience_for_itype{$itype}{$audience} = 1;
	}
}

#locn_suffix for itype for branches
my %locns_for_itype = (
	'0'   => [ qw( a aa ac ar at es ex f fc ff fi fl fm fp fr fw hc ho lh nf nr od oo ps ro sb se sf sl sp ss zz) ], #book
	'1'   => [ qw( ) ], #fbook aka "book (branches)"
	'2'   => [ qw( bd bg bi eb ec er f fl gn ho nf oo ps pu se ) ], #jbook
	'3'   => [ qw( ) ], #fjbook
	'4'   => [ qw( ar bl f fh fs gn nf od oo zz ) ], #teen book
	'5'   => [ qw( ) ], #ftbook
	'10'  => [ qw( ac hc lr r ra rd rf ro rr ) ], #reference book
	'11'  => [ qw( r rd rf ro ) ], #ref jbook
	'12'  => [ qw( r rd rf ro ) ], #teen ref jbook
	'15'  => [ qw( fl ) ], #braille
	'16'  => [ qw( ) ], #ref braille
	'17'  => [ qw( ) ], #gov doc
	'18'  => [ qw( ) ], #ref gov doc
	'20'  => [ qw( l lf ln ) ], #largeprint
	'21'  => [ qw( ) ], #branch largeprint
	'22'  => [ qw( f l nf ) ], #jlargeprint
	'23'  => [ qw( ) ], #branch jlargeprint
	'24'  => [ qw( f l nf ) ], #teen largeprint
	'30'  => [ qw( nf mc mg oo ) ], #magazine
	'31'  => [ qw( mg ) ], #jmag
	'32'  => [ qw( mg ) ], #tmag
	'33'  => [ qw( mg oo r rd rf ro ) ], #ref mag
	'34'  => [ qw( r rd rf ro ) ], #ref juv mag
	'35'  => [ qw( r rd rf ro ) ], #ref tee mag
	'37'  => [ qw( nw rd ) ], #newspaper
	'46'  => [ qw( ac ) ], #rare book
	'60'  => [ qw( ab at ao of ) ], #cassbook,fcassbook
	'61'  => [ qw( au ab ) ], #jcassbook
	'62'  => [ qw( au ab of ) ], #ref book on cassette
	'65'  => [ qw( cz ho ) ], #music cassette
	'66'  => [ qw( ck cz ho ) ], #j music cassette
	'67'  => [ qw( r rd rf ro ) ], #ref music cassette
	'70'  => [ qw( ab ac af ao c fl ho ) ], #cd-book
	'71'  => [ qw( ab au c ) ], #j cd-book
	'72'  => [ qw( ab ) ], #t cd-book
	'73'  => [ qw( ab of) ], #ref book on cd
	'77'  => [ qw( ar c cb cc ce cf cg ch ci cj ck cl cm cn co cp cq cr cs cv cw cx ho od oo ) ], #cd-music
	'78'  => [ qw( au c ho ) ], #j cd-music
	'79'  => [ qw( r rd rf ro of ) ], #ref music on cd
	'82'  => [ qw( al ) ], #lp record
	'83'  => [ qw( ) ], #ref lp record
	'90'  => [ qw( pl ) ], #playaway
	'91'  => [ qw( pl ) ], #j playaway
	'92'  => [ qw( pl ) ], #t playaway
	'93'  => [ qw( pl ) ], #playaway view
	'94'  => [ qw( pl ) ], #ref playaway view
	'100' => [ qw( dn oo ) ], #new video
	'101' => [ qw( d da dc df dm dr ds dt du v vm ) ], #video
	'103' => [ qw( r rd rf ro of ) ], #ref video
	'104' => [ qw( d ) ], # video kit 
	'111' => [ qw( mh td ) ], # portable technology device 
	'120' => [ qw( ) ], #downloadable audio
	'121' => [ qw( ) ], #downloadable music
	'122' => [ qw( ) ], #downloadable video
	'123' => [ qw( ) ], #downloadable book
	'134' => [ qw( cy ) ], #cd-roms
	'144' => [ qw( ma ) ], #map
	'157' => [ qw( ar ho nf ) ], #score
	'158' => [ qw( ) ], #branch score
	'159' => [ qw( ho nf ) ], #jscore
	'160' => [ qw( ) ], #fjscore
	'162' => [ qw( r rd rf ro ) ], #jscore ref
	);
my %is_locn_for_itype;
for my $itype (keys %locns_for_itype) {
    for my $locn ( @{$locns_for_itype{$itype}} ) {
        $is_locn_for_itype{$itype}{$locn} = 1;
    }
}

#full locn for itype
my %main_locns_for_itype = (
	'0'   => [ qw( 	1cjfs 1cjps 1fa   1haoo 1paa  1paaa 1paar 1paes 1pafc 1paff 1pafh 1pafi 1pafl 1pafm 1pafp 1pafr 1pafs 1pafw
					1pagn 1paho 1panf 1panr 1pass 1pasl 1pasp 1paoo 
					2ea   2ga   2ra   2raar 2rabi 2rabu 2raca 2rage 2ragt 2raod 2raoo 2sa   2ttrd 2ttrf 2ttro 2x    2xoo  2xrt
					3aa   3darn 3ea   3ear  3ga   3gaa  3galh 3gaod 3gaoo 3ha   3la   3ra 
					4ca   4ra   4raoo 4da
					osaf osaex osaho osanf
				 ) ], #book

	'2'   => [ qw(	1cj   1cjar 1cjbd 1cjbg 1cjeb 1cjer 1cjfl 1cjho 1cjnf 1cjod 1cjoo 1cjps 1cjpu 1cjsb 1cjsf
			1lj   1ljsf 1ljbd 1ljer 1hj   1hja  1hjoo 
			osjbd osjbg osjbi osjeb osjec osjer osjex osjf  osjfl osjgn osjho osjnf osjse
				) ], #jbook

	'4'   => [ qw( 	1pafc 2tt   2ttab 2ttar 2ttbi 2ttf  2ttfh 2ttfs 2ttgn 2ttnf 2ttod 2ttoo 2ttpb 2ttt  2kt
			ostbi ostex ostf  ostgn ostnf
				) ], #teen book

	'10'  => [ qw( 	1cjrd 1cjrf 1cjro 1lj   1fa   1pard 1parf 1paro 
					2ea   2ga   2ma   2na   2rabr 2racr 2rage 2ragr 2rar  2rard 2raro 2rabu 2raca 2raqt 2sa   2xrf
					3aa   3aaac 3ca   3cacr 3caod 3caoo 3carv 3da   3darc 3dard 3darf 3darn 3daro 3dars 
					3ea   3ear  3galr 3gaoo 3gar  3gara 3gard 3garo 3gasc 3garr 3ha   3la 
					4da 4va   4vaoo
					osaf  osaho osanf osar osast
				) ], #reference book

	'11'  => [ qw(  1cjrd 1cjrf 1cjro 1lj   1hj   1hja  1hjrf osjr ) ], #ref jbook
	'12'  => [ qw(  2kt   2ttrd 2ttrf 2ttro osast ) ], #teen ref jbook
	'15'  => [ qw(  1cj   1cjar 1cjsu 1cjbd 1cjbg 1cjeb 1cjer 1cjfl 1cjho 
			1cjnf 1cjod 1cjoo 1cjps 1cjpu 1cjrd 1cjrf 1cjro 1cjsb 1cjsf
			1lj   1ljbd 1ljer 
			osjeb osjex
				) ], #braille
	'16'  => [ qw(  1lj ) ], #ref braille
	'17'  => [ qw(  2ea   2ga  3ha  2ra  2sa  3aa  3ra   4da  osamg ) ], #gov doc
	'18'  => [ qw(  2ea  2ga   2rar  2rard  2raro  3ra 3ha  4da   2ra ) ], #ref gov doc
	'20'  => [ qw(  1fa   1paff 1pal  1paoo 2ea 2ra 3ra  osal ) ], #largeprint
	'22'  => [ qw(  1cj   1cjar 1cjod 1lj   1cjoo osjf osjnf ) ], #jlargeprint
	'24'  => [ qw(  2kt   2ttar 2ttf  2ttbi 2ttfh 2ttfs 2ttnf 2ttoo ostf ostnf ) ], #teen largeprint
	'26'  => [ qw(  2ea   2ra   2rar 2raro  3ha  osast ) ], #ref large print
	'27'  => [ qw(  osjr  ) ], #ref juv large print
	'30'  => [ qw(  2ea   2raar 2ragt  2sa   2ga   3aa   3ea   3la   3ha  3ra  1lj   2ma   
2mamc 2mamh 2maoo 2na osamg osaml ) ], #magazine
	'31'  => [ qw(  1cj   1cjoo 1lj osjmg ) ], #jmag
	'32'  => [ qw(  2kt   2ttmg ) ], #tmag
	'33'  => [ qw(  2ea   2sa   2ga   2rar 2rard  3aa   3ca   3cacr 3caod 3caoo 3carv 
3ea   3la   3ha   3ga   3garr 1lj   2ma   2maoo 2na   3galr 3ca osamg osaml ) ], #ref mag
	'34'  => [ qw(  1cj   1cjoo 1lj   1cjrd 1cjrf 1cjro 1hjrf osjmg ) ], #ref juv mag
	'35'  => [ qw(  2kt   2ttmg 2ttrd 2ttro 2ttrf ) ], #ref tee mag
	'37'  => [ qw(  2ga   2ma   2na   2maoo ) ], #newspaper
	'46'  => [ qw(  3aaac 3ca   3cacr 3caod 3caoo 3carv 3da   3darc 3dard 3gasc ) ], #rare book
	'60'  => [ qw(  1fa   1pafl osaab ) ], #cassbook,fcassbook
	'61'  => [ qw(  1lj   1cjau 1cjfl 1cjho 1cjod osjab osjck osjho ) ], #jcassbook
	'62'  => [ qw(  1fa   1paof 1pard 1parf 1paro ) ], #ref book on cassette
	'65'  => [ qw(  1fa   osacz ) ], #music cassette
	'66'  => [ qw(  1lj   1cjau 1cjfl 1cjho 1cjod osjcz ) ], #j music cassette
	'67'  => [ qw(  1fa   1paof 1pard 1parf 1paro osacz ) ], #ref music cassette
	'70'  => [ qw(  1fa   1paab 1pac  1paes 1paoo 1paff 1pafl 1pacn 1paho 1pasl osaab osac ) ], #cd-book
	'71'  => [ qw(  1cjoo 1cjau 1cjfl 1cjho 1cjod 1lj osjab ) ], #j cd-book
	'72'  => [ qw(  2ttoo 2ttab 2kt   ostab ) ], #t cd-book
	'73'  => [ qw(  1fa   1paar 1paoo 1paof 1pard 1parf 1paro osaab ) ], #ref book on cd
	'77'  => [ qw(  1fa   1paoo 1pacb 1pacc 1pace 1pacf 1pacg 1pach 1paci 1pacj 1pack 1pacl 1pacm 1pacn 1paco 1pacp 1pacq
					1pac  1pacr 1pacs 1pacv 1pacw 1pacx 1paho osac ) ], #cd-music
	'78'  => [ qw(  1cjau 1cjho 1cjfl 1cjod 1cjoo 1lj osjc ) ], #j cd-music
	'79'  => [ qw(  1fa   1paoo 1paof 1pard 1parf 1paro osac  osar  osjr ) ], #ref music on cd
	'82'  => [ qw(  1fa   1paal 1paho osast ) ], #lp record
	'83'  => [ qw(  1fa   1paal osast ) ], #ref lp record
	'90'  => [ qw(  1fa   1paho 1paoo 1papl osapl ) ], #playaway
	'91'  => [ qw(  1fa   1lj   1cjod 1cjoo 1cjau osjpl ) ], #j playaway
	'92'  => [ qw(  1fa   2ttoo 2ttab 2kt   ostpl ) ], #t playaway
	'93'  => [ qw(  1fa   1paoo 1papl osapl ) ], #playaway view
	'94'  => [ qw(  1fa   1paoo 1paof 1pard 1parf 1paro osapl ) ], #ref playaway view
	'100' => [ qw(  1paoo 1padn osad ) ], #new video
	'101' => [ qw(  1cjps 1fa   1paoo 1pada 1padc 1padf 1padm 1padr 1pads 1padt 1padu 1paes 1pafl 1paho 1pavm 1pjd  1pajd 1pjdm 2ttda osad osav ) ], #video
	'103' => [ qw(  1fa   1paoo 1paof 1pard 1parf 1paro osav ) ], #ref video
	'111' => [ qw(  4camh ) ], # portable technology device
	'131' => [ qw(  3aa ) ], #arch drawing
	'132' => [ qw(  3aa   3ea ) ],  #archival material
	'134' => [ qw(  1cj   1lj   1cjau 1fa   1pacy 1pafl 1paof ) ], #cd-roms
	'135' => [ qw(  1paro 2ea   2sa   2ga   3aa   3ea   3la   3ha   1lj )], #ref cd-rom
	'137' => [ qw ( 3ha ) ], # globe
	'138' => [ qw(  osak  osjk ) ], #unknown graphic
	'139' => [ qw ( 2ga  3aa ) ], # reference graphic
	'141' => [ qw(  1cjps 1fabc osak ) ], #kit
	'142' => [ qw(  1fabc osjk ) ], #juv kit
	'143' => [ qw(  1fabc ) ], #teen kit
	'144' => [ qw(  2ga   2sa   3eama 3gama 3ga   3ea   3ha ) ], #map
	'148' => [ qw(  osak  osjk ) ], #picture
	'149' => [ qw(  3aa osak ) ], #ref picture
	'151' => [ qw(  3aa 3ha ) ], #poster/print
	'152' => [ qw(  3ha ) ], #ref poster/print
	'154' => [ qw(  3aa ) ], #ref print
	'155' => [ qw(  1lj   1fa   2ga   2sa   3aa   3aaac 3ca   3cacr 3caod 3caoo 3carv 
	                os    osa   osaab osabi osac  osacz osad  osafl osaho osal  osanf osaoo osapl osase osast osav  
	                osj   osjab osjbd osjbi osjc  osjck osjcz osjeb osjec osjer osjex osjey 
	                osjf  osjfl osjho osjnf osjoo osjpl osjr  osjse ost   ostf  ostoo ostpl oszzz ) ], #realia
	'157' => [ qw(  2ea 2ra 2raoo 3aa 3ra   osaf  osaho osanf ) ], #score

	'159' => [ qw(  1cjar 1cjod 1cjoo 1cjnf 1cjho 1lj osjho osjnf ) ], #jscore
	'161' => [ qw(  2ea 2ra 2raoo 2rar  2rard 2raro 3aa osast ) ], #ref music score
	'162' => [ qw(  1cjoo 1lj   1cjrd 1cjrf 1cjro osjr ) ], #jscore ref
	);
my %is_main_locn_for_itype;
for my $itype (keys %main_locns_for_itype) {
    for my $locn ( @{$main_locns_for_itype{$itype}} ) {
        $is_main_locn_for_itype{$itype}{$locn} = 1;
    }
}

#bcode2 for itype
my %itypes_for_bcode2 = (
	'a' => [ qw( 0 1 2 3 4 5 10 11 12 15 16 46 132 ) ], #book
	'b' => [ qw( 0 10 17 18 ) ], #govdoc
	'c' => [ qw( 157 158 159 160 161 162 ) ], #score
	'e' => [ qw( 0 2 4 10 11 12 137 144 )], #map
	'g' => [ qw( 100 101 103 104 ) ], #dvd
	'h' => [ qw( 100 101 103 ) ], #vhs
	'i' => [ qw( 70 71 72 73 ) ], #cd-book
	'j' => [ qw( 77 78 79 ) ], #cd-music
	'l' => [ qw( 20 21 22 23 26 27 ) ], #largeprint
	'm' => [ qw( 134 135 ) ], #cd-rom
	'n' => [ qw( 30 33 37 ) ], #newspaper
	'q' => [ qw( 90 91 92 93 94 ) ], #playaway
	's' => [ qw( 10 30 31 32 33 34 35 ) ], #magazine
	'v' => [ qw( 126 ) ], #web document
	'w' => [ qw( 127 ) ], #website
	'x' => [ qw( 125 ) ], #e-magazine
	'y' => [ qw( 124 ) ], #e-newspaper
	'z' => [ qw( 121 122 123 124 125 126 127 ) ], #e-resource??
	'1' => [ qw( 120 ) ], #downloadable audiobook
	'2' => [ qw( 123) ], #downloadable book
	'3' => [ qw( 121 ) ], #downloadable music
	'4' => [ qw( 122 ) ], #downloadable video
	'5' => [ qw( 60 61 62 ) ], #cass-book
	'6' => [ qw( 145 146 ) ], #microform
	'7' => [ qw( 65 66 67 ) ], #cass-music
	'8' => [ qw( 82 83 ) ], #lp record
	'9' => [ qw( 131 132 136 138 139 147 148 149 151 152 154 163 ) ], # 2-D Graphic
	'-' => [ qw( 111 130 132 136 137 138 139 140 141 142 143 144 147 148 149 151 152 154 155 163 165) ] #undefined
);
my %is_bcode2_for_itype;
for my $bcode2 (keys %itypes_for_bcode2) {
    for my $itype ( @{$itypes_for_bcode2{$bcode2}} ) {
        $is_bcode2_for_itype{$itype}{$bcode2} = 1;
    }
}

# branch locations for non-floating branch itypes
my %branch_prefixes_for_nonfloating_itypes = (
	'104' => [ qw( gr ) ], # video kit, only at SYMMES as pilot 20160829
	'111' => [ qw( av co gr wh ) ] # portable technology device, added to rept 20160829.  Will not show on report b/c '-' bcode2 excluded in query. 
);

my %is_branch_prefix_for_nonfloating_itype;
for my $itype (keys %branch_prefixes_for_nonfloating_itypes) {
	for my $libr ( @{$branch_prefixes_for_nonfloating_itypes{$itype}} ) {
		$is_branch_prefix_for_nonfloating_itype{$itype}{$libr} = 1;
	}
}

#itypes to ignore for this report
my %is_itype_to_skip = map { $_ => 1 } qw( 145 146 163 );

#"teen classics" record numbers
# TODO: consider loading this from another file
my %is_teen_classic = map { $_ => 1 } qw ( 	1005070
											1008088
											1008092
											1008324
											1009074
											1012471
											1012960
											1016931
											1023324
											1025647
											1026944
											1030135
											1032779
											1033764
											1035984
											1036364
											1038132
											1041785
											1042130
											1044943
											1045391
											1057164
											1068843
											1069142
											1080942
											1098072
											1123311
											1125257
											1131252
											1136783
											1137858
											1149649
											1156722
											1163065
											1195037
											1198983
											1208160
											1208782
											1214946
											1258923
											1260206
											1262052
											1262195
											1263884
											1268373
											1268384
											1274970
											1276299
											1283114
											1285037
											1318751
											1321722
											1328024
											1330867
											1332284
											1375132
											1376771
											1386082
											1392809
											1395441
											1405850
											1417890
											1422875
											1427726
											1465219
											1465868
											1473691
											1476334
											1482199
											1500156
											1500725
											1519112
											1519118
											1520620
											1521555
											1523209
											1524032
											1524039
											1524049
											1528683
											1534705
											1542739
											1555182
											1557339
											1557775
											1564639
											1573242
											1579598
											1584994
											1596027
											1610988
											1630040
											1637976
											1639082
											1639351
											1657016
											1657539
											1723544
											1732910
											1748806
											1750917
											1751512
											1753059
											1756363
											1765488
											1777013
											1777554
											1789689
											1798623
											1806397
											1815906
											1821901
											1823479
											1824853
											1824863
											1824881
											1837580
											1874105
											1874105
											1874617
											1881635
											1891612
											1893725
											1900878
											1915536
											1933582
											1934753
											1960352
											1961576
											1961887
											1967302
											1986993
											1992305
											1996454
											2005510
											2006956
											2006985
											2008273
											2012712
											2014369
											2028943
											2040871
											2048799
											2052473
											2069758
											2070459
											2080910
											2081561
											2086313
											2089850
											2092147
											2092155
											2111249
											2118284
											2130304
											2133134
											2137975
											2169420
											2171086
											2186599
											2203330
											2203330
											2203367
											2204141
											2210745
											2212066
											2215585
											2220611
											2225085
											2228373
											2229190
											2229649
											2252851
											2264431
											2265447
											2268806
											2270361
											2315417
											2325236
											2330280
											2331675
											2349894
											2377225
											2385659
											2388695
											2390408
											2399213
											2401846
											2402050
											2403296
											2424769
											2427365
											2439149
											2449995
											2454966
											2460026
											2467038
											2476394
											2476870
											2487394
											2492541
											2493883
											2494668
											2508710
											2518435
											2526514
											2530079
											2530507
											2532883
											2538123
											2540289
											2540405
											2547935
											2556742
											2560158
											2566314
											2572417
											2574892
											2578161
											2592633
											2598018
											2610287
											2610368
                                                                                     2611069
											2611525
											2613714
											2615465
											2615487
											2615515
											2615605
											2615620
											2615705
											2615908
											2619886
											2624870
											2628120
											2628125
											2638970
											2640657
											2643029
											2654111
											2659891
											2663126
											2667577
											2670636
											2670823
											2676813
											2693063
											2697347
											2702313
											2712108
											2712532
											2712549
											2712608
											2713686
											2713850
											2726440
											2729046
											2738268
											2739884
											2741117
											2772166
											2784353
											2784616
											2785618
											2788500
											2792223
											2792790
											2823065
											2883551
											2886553
											2963099
											2969363
											2972940
											2994736
											3134360
											3192709
											3193734
											3202674
											3285022
											3293824
											1416907
2493664
2985934
2985935
2493587
1803522
2755125
2714814
2500300
2985933
3108309
3108308
2884705
2275400
3229667
1803502
1803512
2275489
2985932
2981982
1832463
1971745
1770999
										   );
# RV 2017-08-01
# 3293824 is not a teen classic, but adding it to the list to ignore 

# RV 2017-11-03
# added bibs starting at 1416907 and continuing to 1770999

#------------------------------------------------------------------------------------------------------------------------
# DB Setup
my $db_host = $cfg->param("DatabaseHost");
my $db_port = $cfg->param("DatabasePort");
my $db_user = $cfg->param("DatabaseUser");
my $db_pass = $cfg->param("DatabasePass");
print " + We're connecting to ".$db_host." for SQL query...\n";
	print "++++++++++++++++++++++++++++++++++\n";
my $dbh = DBI->connect("DBI:Pg:dbname=iii;host=".$db_host.";port=".$db_port."",$db_user,$db_pass,{'RaiseError'=>0});

#object that holds all the errors
my %shelflist;

#loop setup
my $first_item = 0; 
$first_item = lowest_item_row_id();  #uses SQL
my $last_item = 0;
$last_item = highest_item_row_id();  #uses SQL

my $chunk_size = 100000;  #TODO: consider parameterizing this from slitemdata.cfg
my $chunk_begin = $first_item;
my $chunk_end = $chunk_begin + $chunk_size;

#queries the item table in chunks to avoid timeouts getting 8M+ items
while ( $chunk_begin < $last_item )
{
	#Build DB Query for this chunk
	my $sql_query 	 = "SELECT ";
		$sql_query .= "sierra_view.item_view.record_num, ";
		$sql_query .= "sierra_view.item_view.itype_code_num, ";
		$sql_query .= "sierra_view.item_view.location_code, ";
		$sql_query .= "sierra_view.item_view.last_checkout_gmt, ";

		$sql_query .= "sierra_view.bib_view.bcode2, ";
		$sql_query .= "sierra_view.bib_view.record_num as bib_record_num, ";

		$sql_query .= "sierra_view.bib_record_property.best_title, ";
		$sql_query .= "sierra_view.bib_record_property.best_author, ";

		$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
		$sql_query .= "FROM sierra_view.varfield_view ";
		$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.item_view.record_num AND ";
		$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'i' AND ";
		$sql_query .= "		 sierra_view.varfield_view.varfield_type_code = 'b' ";
		$sql_query .= "LIMIT 1 ) as real_barcode, ";

		$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
		$sql_query .= "FROM sierra_view.varfield_view ";
		$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
		$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
		$sql_query .= "		 sierra_view.varfield_view.varfield_type_code = 'c' ";
		$sql_query .= "LIMIT 1 ) as callnum ";

		$sql_query .= "FROM sierra_view.item_view ";
		
		$sql_query .= "JOIN sierra_view.bib_record_item_record_link ";
		$sql_query .= "ON   sierra_view.bib_record_item_record_link.item_record_id = sierra_view.item_view.id ";

		$sql_query .= "JOIN sierra_view.bib_view ";
		$sql_query .= "ON   sierra_view.bib_view.id = sierra_view.bib_record_item_record_link.bib_record_id ";

		$sql_query .= "JOIN sierra_view.bib_record_property ";
		$sql_query .= "ON   sierra_view.bib_record_property.bib_record_id = bib_view.id ";

		$sql_query .= "WHERE ";
		$sql_query .= "sierra_view.item_view.is_suppressed = FALSE ";					#exclude suppressed items altogether
		$sql_query .= "AND sierra_view.bib_view.bcode3 != 's' ";					#exclude Symphony Suppressed
		$sql_query .= "AND sierra_view.bib_view.bcode2 != '-' ";					#exclude Mat Type = undefined
		$sql_query .= "AND sierra_view.item_view.item_message_code != 'f' ";				#exclude On The Fly
		$sql_query .= "AND sierra_view.item_view.itype_code_num NOT IN ( 136, 145, 146, 163 ) "; 	#exclude certain itypes
		$sql_query .= "AND sierra_view.item_view.item_status_code NOT IN ( 'p', 'u' ) "; 		#exclude items in certain statuses
		
		$sql_query .= " AND sierra_view.item_view.id >= " . $chunk_begin . " ";
		$sql_query .= " AND sierra_view.item_view.id <= " . $chunk_end . " ";
		
		$sql_query .= ";";

	my $s = SQL::Beautify->new;
	$s->query($sql_query);
	my $nice_sql = $s->beautify;
	print $nice_sql."\n";

	#DB chunk query subroutine returns an sth to be processed
	my $sth = item_chunk_query( $sql_query , $dbh );

	#------------------------------------------------------------------------------------------------------------------------
	# Process results
	#
	#  this loop takes the $sth and puts any item errors into the %shelflist

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		my $record_num = 	( defined $item_info->{'record_num'}		) ? $item_info->{'record_num'} 			: '';
		my $itype = 		( defined $item_info->{'itype_code_num'}	) ? $item_info->{'itype_code_num'}		: '';
		my $location_code =	( defined $item_info->{'location_code'}     ) ? $item_info->{'location_code'}		: '';
		my $barcode =		( defined $item_info->{'real_barcode'}     	) ? $item_info->{'real_barcode'}		: '';
		my $callnum = 		( defined $item_info->{'callnum'}			) ? $item_info->{'callnum'}				: '';
		my $title =			( defined $item_info->{'best_title'}		) ? $item_info->{'best_title'}			: '';
		my $author =		( defined $item_info->{'best_author'}		) ? $item_info->{'best_author'}			: '';
		my $lcharged = 		( defined $item_info->{'last_checkout_gmt'} ) ? $item_info->{'last_checkout_gmt'} 	: '';
		my $bcode2 = 		( defined $item_info->{'bcode2'} 			) ? $item_info->{'bcode2'} 				: '';
		my $bib_record_num =( defined $item_info->{'bib_record_num'} 	) ? $item_info->{'bib_record_num'} 		: '';

		$callnum =~ s/\|a//i;	
		$callnum =~ s/\|b/ /i;

		#parse the location code into chunks
		my $libr = substr( $location_code, 0, 2 );
		my $audience = ( length $location_code > 2 ) ? substr( $location_code, 2, 1 ) : "";
		my $locn_suffix = ( length $location_code > 3 ) ? substr( $location_code, 3, 2 ) : "";

		my @errors = ();	

		#skip virtual and offsite , etc items
		#TODO: consider moving these exclusions to the SQL query
		if(    !$is_location_offsite{$location_code} 
			&& !$is_location_virtual{$location_code} 
			&& !$is_location_innreach{$location_code} #TODO: is this correct?
			&& !$is_location_administrative{$location_code} 
			#&& !$is_itype_to_skip{$itype} #145,146,163
			&& $location_code ne 'zzzzz' )
		{

			#TEST: bcode2 for itype
			if ( !$is_bcode2_for_itype{$itype}{$bcode2}
				&& $bcode2 ne 'r'
				&& $bcode2 ne 't'
				&& $bcode2 ne 'o'
				&& $bcode2 ne 'p'
			 )
			{
				#print "Bad bcode2 for itype: ";
				#print "[ " . $barcode . " ] ";
				#print $itype . " " . $bcode2 . " " . $location_code . " ";
				#print "\n";
				push @errors, "Format (MatType) and Item Type are not consistent.";
			}

			#LOCATION TESTS
			if  ( !$is_branch_prefix{$libr} )  #if main item, do this test: is_main_loc_for_itype
			{
				#TEST: locn for itype
				if(    !$is_main_locn_for_itype{$itype}{$location_code} 
				    && !( $is_teen_classic{$bib_record_num}) 	#don't put the teen classic titles through this check
				    && $location_code ne '1paar'  	 			#don't put POP new arrivals through this check
				    && $location_code ne '1paod'
				    && $location_code ne '1paof'
				    && $location_code ne '3calh' #per vicki 08/2015
				    && !($location_code =~ /...oo/ )
				  )
				{
					print "Bad locn for itype: ";
					print "[ " . $barcode . " ] ";
					print $itype . " " . $location_code . " ";
					print "\n";
					push @errors, "Item Type and Main Location are not consistent.";
				}
			}
			else  #else do these tests for branch stuff
			{
				#TEST: locn ( audience ) for itype
				if(    !$is_audience_for_itype{$itype}{$audience} 
					&& !( $is_teen_classic{$bib_record_num} )  #don't put the teen classic titles through this check
				  )
				{
					#print "Bad audience for itype: ";
					#print "[ " . $barcode . " ] ";
					#print $itype . " " . $audience . " " . $location_code . " " ; 
					#print "\n";	
					push @errors, 'Item Type and Branch Location (Audience) are not consistent.';
				}

				#TEST: locn ( suffix ) for itype
				if(    !$is_locn_for_itype{$itype}{$locn_suffix} 
					&& !( length $location_code == 3 && !$is_branch_prefix{$libr}) #3-letter codes allowed at main and outreach
				    && !( $is_teen_classic{$bib_record_num} )  #don't put the teen classic titles through this check
				    && !($location_code =~ /...oo/ )
				  )
				{
					print "Bad locn for itype: ";
					print "[ " . $barcode . " ] ";
					print $itype . " " . $locn_suffix . " " . $location_code . " ";
					print "\n";
					push @errors, "Item Type and Branch Location (Suffix) are not consistent.";
				} 

				#TEST: locn ( prefix ) for itype -- new 20160829
				if (( $itype eq '104' || $itype eq '111') && !$is_branch_prefix_for_nonfloating_itype{$itype}{$libr} )
				{
					print "Bad locn for itype: ";
					print "[ " . $barcode . " ] ";
					print $itype . " " . $libr . " ";
					print "\n";
					push @errors, 'Non-floating item type at an incorrect branch location.'; 
				}
			
			}
		}

		#add any errors found to the shelflist
		if ( scalar @errors)
		{
			$shelflist{$libr}{'item'}{$barcode} = {  #TODO?
				'catkey' => 'catkey', #not sure if this is needed
				'callseq' => 'callseq', #not sure how this was used
				'type' => { 'id' => $itype, 'content' => $itype_names_hash{$itype} },
				'hlocn' => { 'id' => $location_code, 'content' => $location_code },
				'clocn' => { 'clocn' => 'clocn', 'content' => 'clocn' }, #TODO: is this needed?
			};
			$shelflist{$libr}{'item'}{$barcode}{'audience'} = { 'id' => $audience, 'content' => $audience } if $audience;
			#$shelflist{$libr}{'item'}{$barcode}{'category1'} = { 'id' => $ict1, 'content' => $directive_ref->{'ICT1'}{$ict1} } if $ict1; #TODO: bibmattype/bcode2
			$shelflist{$libr}{'item'}{$barcode}{'lcharged'} = { 'date' => $lcharged, 'content' => $lcharged };
			$shelflist{$libr}{'item'}{$barcode}{'errors'}{'error'} = \@errors;
			$shelflist{$libr}{'item'}{$barcode}{'title'}{'content'} = $title;
			$shelflist{$libr}{'item'}{$barcode}{'title'}{'sort'} = $title;
			$shelflist{$libr}{'item'}{$barcode}{'author'}{'content'} = $author;
			$shelflist{$libr}{'item'}{$barcode}{'author'}{'sort'} = $author;
			$shelflist{$libr}{'item'}{$barcode}{'callnum'}{'content'} = $callnum;
		}
		
	}
	
	#move to the next chunk, repeat...
	$chunk_begin = $chunk_end + 1;
	$chunk_end = $chunk_begin + $chunk_size;

} #end overall SQL/Process loop
#------------------------------------------------------------------------------------------------------------------------

#out of curiousity, output size of shelflist
foreach my $l ( sort keys %shelflist )
{
	print $l . ": " . scalar( keys %{ $shelflist{$l}{'item'} } ) . "\n";
}

#------------------------------------------------------------------------------------------------------------------------
# Converts the huge %shelfist to XML and uploads to main12

my $destination = $cfg->param("OutputDir");
my $ftp_host = $cfg->param("FTPHost");
my $ftp_user = $cfg->param("FTPUser");
my $ftp_pass = $cfg->param("FTPPass");

$destination = ( defined $destination ) ? $destination : '/sierra/test/shelflist/itemdata'; 
print " + Output Dir is: " . $destination . "\n";

my $ftp = Net::FTP->new( $ftp_host, Debug => 0 ) or die "Cannot connect to $ftp_host: $@";
$ftp->login( $ftp_user, $ftp_pass ) or die "Cannot login $destination", $ftp->message;
$ftp->ascii;
$ftp->cwd($destination) or die 'failed to change to directory ', $ftp->message;

chomp(my $today = `date +'%B %e, %Y'`);

my %index;
$index{'generated'}   = $today; 
$index{'title'}       = "Item Data Consistency";
$index{'description'} = "item data consistency";

my %file_list;

for my $libr (keys %shelflist){
	my $filename  = "\L$libr.xml";

        $index{'library'}{$libr} = { 'filename' => $filename, 'content' => $location_name_for_location_code{$libr} };

        $shelflist{$libr}{'libr'}        = $libr;
        $shelflist{$libr}{'library'}     = $location_name_for_location_code{$libr};
        $shelflist{$libr}{'generated'}   = $today;
        $shelflist{$libr}{'title'}       = "Item Data Consistency";
        $shelflist{$libr}{'description'} = "item data consistency";
        $file_list{$libr} = './temp/' . "$libr.xml";
        XMLout(
            $shelflist{$libr},
            KeyAttr => { 'item' => 'id' },
            NumericEscape => 2,
            OutputFile => $file_list{$libr},
            RootName => 'shelflist',
            SuppressEmpty => 1,
            XMLDecl => 1,
        );
	$ftp->put($file_list{$libr}, $filename);
}
$file_list{'index'} = './temp/' . "index.xml";
XMLout(
	\%index,
	KeyAttr => { 'library' => 'id' },
	NumericEscape => 2,
	OutputFile => $file_list{'index'},
	RootName => 'index',
	SuppressEmpty => 1,
	XMLDecl => 1,
);

$ftp->put($file_list{'index'}, 'index.xml');
$ftp->quit;


#------------------------------------------------------------------------------------------------------------------------

print "++++++++++++++++++++++++++++++\n";
print "Item Data Inconsistency Report done.\n";
my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
$hhmmss = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
print "script finish at ".$hhmmss."...\n";
print "++++++++++++++++++++++++++++++\n";


