#!/usr/bin/perl -w
############################################################
#
# mib_lvm.pl -- SNMP handler for the lvm operation
#
# Author:            Qu Haiping
#            National Research Center
#          for High Performace Computers
#
# Create Date:      2005/05/28
#
#         CopyRight (C) 2005 NRCHPC, China
#
############################################################

# Persistant perl script to respond to pass-through smnp requests
# put the following in your snmpd.conf file to call this script:
# pass_persist .1.3.6.1.4.1.19039.23  /etc/snmp/mib_lvm.pl

#
# $Date: 2005/10/26 08:51:12 $
# $Source: /cvsroot/lvm-mib/perl/mib_lvm.pl,v $
# $Revision: 1.1 $
#


# Forces a buffer flush after every print
$|=1;

use strict;

my $place = ".1.3.6.1.4.1.19039.23";

my ( @vgs , @lvs ) ;
my ( $vgnum , $lvnum ) ;

my $lvinfo = "/tmp/lvinfo" ;

while (<>){
 
  if (m!^PING!){
    print "PONG\n";
    next;
  }

  chomp ( my $cmd = $_ ) ;
  chomp ( my $req = <> ) ;


  if ($cmd eq 'set' ) {
     #Now we inter into set operation
     chomp (my $arg = <> );
     my @args = split (/ / , $arg);
     if ($req =~ /^$place.4.1.6.(\d+)$/) { 
       if ( $args[1] == 5 )  { unlink $lvinfo  ; } 
       else                     { &tableappend($lvinfo, $args[1] ) ; }     
    }
    elsif ($req =~ /^$place.4.1.([1-4])$/) {
         open INFO , ">>$lvinfo"; 
	 print INFO "$1 : $args[1]\n" ;
	 close INFO ; 
    }
    exit 0;  
  }

 
  if (($cmd eq 'get') && (($req eq $place) || ($req =~ /^$place.4.1.[1-5]$/)) ) {  print "NONE\n"; next; } 
  if (($cmd eq 'get') && ($req =~ /^$place.4.1.6.\d+$/))            {  print "$req\ninteger\n2\n";  next;}
  

  unless (defined $vgnum) {
      @vgs = &get_vg_info() ;
      @lvs = &get_all_lvs() ;

      $vgnum  = @vgs ;
      $lvnum  = @lvs ;
   }

  
  if ($cmd eq 'getnext') { $req = &getnext($req) ; }
  unless ( defined $req ) {
  	print "NONE\n" ;
	next ; 
  }
   
  if ($req =~ /^$place.4.1.([1-6]).(\d+)$/) {
	CASE_LV:{
		($1 == 1 ) && do {print "$req\ninteger\n$2\n"                              ; last CASE_LV ; };
		($1 == 2 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'lvname'},"\n"      ; last CASE_LV ; };
		($1 == 3 ) && do {print "$req\ninteger\n",$lvs[$2-1]->{'lvsize'},"\n"      ; last CASE_LV ; };
		($1 == 4 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'vgname'},"\n"      ; last CASE_LV ; };
		($1 == 5 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'snapfrom'},"\n"    ; last CASE_LV ; };
		($1 == 6 ) && do {print "$req\ninteger\n2\n";                                last CASE_LV ; };
       }
  } 	
  elsif ($req =~ /^$place.2.1.([1-7]).([1-$vgnum])$/) {
	CASE_VG:{
		($1 == 1 ) && do {print "$req\ninteger\n$2\n"                           ; last CASE_VG ; };
		($1 == 2 ) && do {print "$req\nstring\n", $vgs[$2-1]->{'vgname'} , "\n" ; last CASE_VG ; };	
		($1 == 3 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'size'} , "\n" ; last CASE_VG ; };
		($1 == 4 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'lvcurrent'}, "\n" ; last CASE_VG ; };
		($1 == 5 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'lvopen'},  "\n" ; last CASE_VG ; };
		($1 == 6 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'pesize'},  "\n" ; last CASE_VG ; };
		($1 == 7 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'peallocated'}, "\n" ; last CASE_VG ; };
		
	}
  }

  elsif ($req eq "$place.1.0" ) {  print "$req\ninteger\n$vgnum\n" ;}

  elsif ($req eq "$place.3.0")  {  print "$req\ninteger\n$lvnum\n" ;}

  else {  print "NONE\n" ;}
}

exit 0 ;

sub getnext {
   my $req = shift ;
   my ( $ret , $next ) ; 
   if  ($req =~ /^$place.4.1.([1-6]).(\d+)$/) {
	if ($2 < $lvnum ) { $next = $2+1 ; $ret = "$place.4.1.$1.$next"  ;}
	elsif ($1 < 6 ) { $next =  $1+1 ; $ret = "$place.4.1.$next.1"  ;}
   }
   elsif ($req =~ /^$place.2.1.([1-7]).([1-$vgnum])$/) {
	if ($2 < $vgnum ) { $next = $2+1 ; $ret = "$place.2.1.$1.$next"  ;}
	elsif ($1 < 7 ) {   $next =  $1+1 ; $ret = "$place.2.1.$next.1"  ;}
   }   
   elsif (($req eq "$place.2" ) || ($req eq "$place.2.1.0") || ($req eq "$place.2.1.1")){
	$ret = $place .".2.1.1.1" ;
   }
   elsif (($req eq "$place.4") ||($req eq "$place.4.1.0")|| ($req eq "$place.4.1.1")){
	$ret = $place .".4.1.1.1"	;
    }  
   else {
	$ret = undef ;
    }
    return $ret ;	
}

sub get_vg_info {
    
    open (FILE , "/proc/lvm/global") || return undef ;
    my ( @vgname , @vgs ) ;
    while (<FILE>){
	chomp ;
        next unless (/^VG:/) ;
	push  @vgname , (split (/ /))[2] ;
    }
    close FILE ;
    for (my $i = 0; $i< @vgname ; $i++ ) {  
        my %vg = ( 'vgname' => $vgname[$i] );        
	my $file = "/proc/lvm/VGs/" . $vgname[$i] ."/group" ;
        my %hash ;
	&read_file ($file , \%vg);
	$vg{"size"} = $vg{"size"} >> 10 ; 
	$vgs[$i] = \%vg ;
   }
   return @vgs ;
}
	 
sub get_all_lvs  {
    my @lvs = ();
    open (FILE , "lvscan |") || return undef ; 
    while (<FILE>) {
	chomp ;
	last unless (/[\"\']([\w\/]+)[\"\']\s+\[(.*)B\]/) ;
	my @array =  split (/\// , $1);
	my %lv = (
	   vgname =>  $array[2]  ,
	   lvname =>  $array[3]  ,
	   lvsize =>  &get_size($2) ,
	   snapfrom => 'NULL' 
	);
        if (/ Snapcopy /) {
		@array = split (/ / ); 
		$lv{'snapfrom'} = $array[$#array] ;
        }
	push (@lvs , \%lv);
   }
   close FILE ;
   return @lvs ;
}

sub get_size {
    my ($value , $item ) = split (/ / , $_[0] ) ;
    return ( $value * 1024 ) if ( $item eq 'G' ) ;
    return $value ; 
}

sub read_file {
    return 1 unless ref $_[1];
    open( FILE, $_[0] ) || return 1;
    while (<FILE>) {
        chomp;
        next if /^\s*#.*/;
        my $eq = index( $_, ":" );
        if ( $eq >= 0 ) {
            my $n = substr( $_, 0, $eq );
            $n =~ s/\s+// ;
            my $v = substr( $_, $eq + 1 );
	    $v =~ s/\s+// ; 
            $_[1]->{lc($n)} = $v;
        }
    }
    close(FILE);
    return 0;
}


sub tableappend {
    my %hash ;
    &read_file($_[0] , \%hash);
    unlink $_[0] ; 
    return 1 unless ((defined $hash{2}) && (defined $hash{4}) ) ;
    if ($_[1] == 2 ) {
	`lvcreate -L $hash{3} -n $hash{2} $hash{4} 1>/dev/null 2>&1 `;
    }
    elsif ($_[1] == 1) {
	`lvcreate -s  -n $hash{2}  $hash{4} 1>/dev/null 2>&1 `;
    }
    elsif ($_[1] == 4) {
	`lvcreate -m  -n $hash{2}  $hash{4} 1>/dev/null 2>&1 `;
    }
    elsif ($_[1] == 6) {
	my $lv = "/dev/" . $hash{4} . "/" . $hash{2} ;  
	`lvremove -f  $lv  1>/dev/null  2>&1 &` ;
    }	
    return 0 ;
}



