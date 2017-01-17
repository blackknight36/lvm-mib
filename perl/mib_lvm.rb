#!/usr/bin/env ruby
############################################################
#
# mib_lvm.rb -- SNMP handler for the lvm operation
#
# Author:            Michael Watters
#                  Dart Container Corp
#
# Create Date:      2017-01-17
#
#         CopyRight (C) 2017 Dart Container
#
############################################################

# Persistant ruby script to respond to pass-through smnp requests
#
# put the following in your snmpd.conf file to call this script:
# pass_persist .1.3.6.1.4.1.19039.23  /etc/snmp/mib_lvm.pl

place = ".1.3.6.1.4.1.19039.23"

def get_vg_info()
    vgs = Array.new
    #vginfo = %x{sudo /usr/sbin/vgs --noheadings -o vg_name,vg_size}

    File.open('lvm-data.txt', 'r') do |vginfo|
    vginfo.each_line do |line|
        line = line.strip!
        #vg_name, size = line.split(/\s+/)
        #vgs["#{vg_name}"] = {'size' => size}
        vghash = Hash[ ['vg_name', 'vg_size'].zip(line.split(/\s+/)) ]
        vgs << vghash
    end
    end

    return vgs
end

def get_all_lvs()
    lvinfo = %x{sudo lvs --noheadings -o lv_name,vg_name,lv_size,origin --units b}
    lvs = Hash.new

    lvinfo.each_line do |line|
        line = line.strip!
        lv_name, vg_name, lv_size, origin = line.split(/\s+/)
        lvs["#{lv_name}"] = {'lv_size' => lv_size[0..-2].to_i, 'vg_name' => vg_name, 'origin' => origin}
    end

    return lvs
end

begin
    loop do
        input = gets.chomp

        if input.downcase == 'ping'
            puts "PONG\n"
        elsif input.downcase == 'get'
            cmd = gets.chomp
            if cmd == place
                puts get_vg_info()
                puts get_all_lvs()
                next
            end
        end
    break if input == 'quit'
    end
end

#sub get_size {
#    my ($value , $item ) = split (/ / , $_[0] ) 
#    return ( $value * 1024 ) if ( $item eq 'G' ) 
#    return $value 
#}

#sub tableappend {
#    my %hash 
#    &read_file($_[0] , \%hash)
#    unlink $_[0] 
#    return 1 unless ((defined $hash{2}) && (defined $hash{4}) ) 
#    if ($_[1] == 2 ) {
#    `lvcreate -L $hash{3} -n $hash{2} $hash{4} 1>/dev/null 2>&1 `
#    }
#    elsif ($_[1] == 1) {
#    `lvcreate -s  -n $hash{2}  $hash{4} 1>/dev/null 2>&1 `
#    }
#    elsif ($_[1] == 4) {
#    `lvcreate -m  -n $hash{2}  $hash{4} 1>/dev/null 2>&1 `
#    }
#    elsif ($_[1] == 6) {
#    my $lv = "/dev/" . $hash{4} . "/" . $hash{2} 
#    `lvremove -f  $lv  1>/dev/null  2>&1 &` 
#    }
#    return 0 
#}
