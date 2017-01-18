#!/usr/bin/perl -w
############################################################
#
# mib_lvm.pl -- SNMP handler for the lvm operation
#
# Author:            Qu Haiping
#            National Research Center
#          for High Performace Computers
#
# Updated to work with LVM2 by Michael Watters <michael.watters@dart.biz>
#
# Create Date:      2005/05/28
#
#         Copyright (C) 2005 NRCHPC, China
#
############################################################

# Persistant perl script to respond to pass-through smnp requests
# put the following in your snmpd.conf file to call this script:
# pass_persist .1.3.6.1.4.1.19039.23  /etc/snmp/mib_lvm.pl

#
# $Date: 2005/10/26 08:51:12 $
# $Source: /cvsroot/lvm-mib/perl/mib_lvm.pl,v $
# $Revision: 1.1 $

# Forces a buffer flush after every print
$|=1;

use strict;

my $place = ".1.3.6.1.4.1.19039.23";

my ( @vgs , @lvs ) ;
my ( $vgnum , $lvnum ) ;

while (<>){

  chomp;

  if (uc($_) eq 'PING') {
    print "PONG\n";
    next;
  }

  chomp ( my $cmd = $_ ) ;
  chomp ( my $req = <> ) ;

  if (($cmd eq 'get') && (($req eq $place) || ($req =~ /^$place.4.1.[1-5]$/)) ) {  print "NONE\n"; next; }
  if (($cmd eq 'get') && ($req =~ /^$place.4.1.6.\d+$/))            {  print "$req\ninteger\n2\n";  next; }

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
        ($1 == 2 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'lv_name'},"\n"      ; last CASE_LV ; };
        ($1 == 3 ) && do {print "$req\ninteger\n",$lvs[$2-1]->{'lv_size'},"\n"      ; last CASE_LV ; };
        ($1 == 4 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'vg_name'},"\n"      ; last CASE_LV ; };
        ($1 == 5 ) && do {print "$req\nstring\n", $lvs[$2-1]->{'snapfrom'},"\n"    ; last CASE_LV ; };
        ($1 == 6 ) && do {print "$req\ninteger\n2\n";                                last CASE_LV ; };
       }
  }

  elsif ($req =~ /^$place.2.1.([1-7]).([1-$vgnum])$/) {
    CASE_VG:{
        ($1 == 1 ) && do {print "$req\ninteger\n$2\n"                           ; last CASE_VG ; };
        ($1 == 2 ) && do {print "$req\nstring\n", $vgs[$2-1]->{'vg_name'} , "\n" ; last CASE_VG ; }; 
        ($1 == 3 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'vg_size'} , "\n" ; last CASE_VG ; };
        ($1 == 4 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'lv_count'}, "\n" ; last CASE_VG ; };
        ($1 == 5 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'vg_extent_size'},  "\n" ; last CASE_VG ; };
        ($1 == 6 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'vg_extent_count'},  "\n" ; last CASE_VG ; };
        ($1 == 7 ) && do {print "$req\ninteger\n",$vgs[$2-1]->{'vg_free_count'},  "\n" ; last CASE_VG ; };
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
    $ret = $place .".4.1.1.1"   ;
    }
   else {
    $ret = undef ;
    }
    return $ret ;
}

sub get_vg_info {
    open (FILE , "sudo /usr/sbin/vgs --noheadings -o vg_name,vg_size,lv_count,vg_extent_size,vg_extent_count,vg_free_count --units b|") || return undef ;
    my ( @vgname , @vgs ) ;

    while (my $row = <FILE>) {
        $row = trim($row);
        chomp($row);

        my ($vg_name, $vg_size, $lv_count, $vg_extent_size, $vg_extent_count, $vg_free_count) = split(/\s+/, $row);

        $vg_size =~ s/B//;
        $vg_size = int($vg_size);

        $vg_extent_size =~ s/B//;
        $vg_extent_size = int($vg_extent_size);

        $vg_extent_count = int($vg_extent_count);
        $vg_free_count = int($vg_free_count);

        my %vg = (
            'vg_name' => $vg_name,
            'vg_size' => $vg_size,
            'lv_count' => $lv_count,
            'vg_extent_size' => $vg_extent_size,
            'vg_extent_count' => $vg_extent_count,
            'vg_free_count' => $vg_free_count
         );
        push @vgs, \%vg ;
    }

   return @vgs ;
}

sub get_all_lvs  {
    my @lvs = ();

    open (FILE , "sudo lvs --noheadings -o lv_name,vg_name,lv_size,origin --units b|") || return undef ;

    while (my $row = <FILE>) {
        $row = trim($row);
        chomp($row);

        my ($lv_name, $vg_name, $lv_size, $origin) = split(/\s+/, $row);

        $lv_size =~ s/B//;
        $lv_size = int($lv_size);

        my %lv = (
            'vg_name' => $vg_name,
            'lv_name' => $lv_name,
            'lv_size' => $lv_size,
            'snapfrom' => $origin
        );
        push (@lvs , \%lv);
    }

   close FILE;
   return @lvs;
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

sub trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}
