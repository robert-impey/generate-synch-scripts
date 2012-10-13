#!/usr/bin/perl -w
use strict;

use Getopt::Long;
use Pod::Usage;

my $man = 0;
my $help = 0;

my ($directory);

GetOptions(
    'help|?' => \$help,
	'man' => \$man,
    'directory|d=s' => \$directory
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

open DIRS, "<$directory/gss.txt" or die $!;
my @directories_file_lines = <DIRS>;
close DIRS;
chomp @directories_file_lines;

my (%container_directories, %rsync_excluded_files);
my $rsync_command;
($rsync_command,
  $rsync_excluded_files{local}, $rsync_excluded_files{remote},
  $container_directories{local}, $container_directories{remote})
    = @directories_file_lines[0..4];
my @dirs_to_synch;
for (6 .. $#directories_file_lines) {
    push @dirs_to_synch, $directories_file_lines[$_];
}

# Make the script to synch the rsync excluded files.

my $sef_script = "$directory/update-rsync-excluded.bat";
unless (-f $sef_script) {
    open SEF, ">$sef_script";
    print SEF <<OUT;
$rsync_command $rsync_excluded_files{local} $rsync_excluded_files{remote}
$rsync_command $rsync_excluded_files{remote} $rsync_excluded_files{local}
OUT

    close SEF;
}

# Make the scripts for synching

for (qw/from to/) {
    my $direction = $_;
    my $synch_script_dir = "$directory/$direction";
    mkdir $synch_script_dir unless -d $synch_script_dir;
    
    for my $dir_to_synch (@dirs_to_synch) {
        my $source = $container_directories{local} . "/$dir_to_synch";
        my $destination = $container_directories{remote} . "/$dir_to_synch";
        
        if ($direction eq 'from') {
            ($source, $destination) = ($destination, $source);
        }
        
        my $synch_script = "$synch_script_dir/$dir_to_synch.bat";
        
        unless (-f $synch_script) {
            open SYNCH, ">$synch_script" or die $!;
            print SYNCH "$rsync_command --exclude-from=$rsync_excluded_files{local} $source/ $destination";
            close SYNCH;
        }
    }
    
    my $all_script = "$synch_script_dir/all.bat";
    unless (-f $all_script) {
        open ALL, ">$all_script";
        for my $dir_to_synch (@dirs_to_synch) {
            print ALL "CALL $dir_to_synch.bat\n";
        }
        close ALL;
    }
}

# Make the script for running everything
my $all_script = "$directory/all.bat";
unless (-f $all_script) {
    open ALL, ">$all_script";
    print ALL <<OUT;
CD "$directory"
CALL update-rsync-excluded.bat
CD to
CALL all.bat
CD ..\\from
CALL all.bat
CD ..
OUT

    close ALL;
}

__END__

=head1 NAME

    sample - Using GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

    sample [options] [file ...]
     Options:
       -help            brief help message
       -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do someting
useful with the contents thereof.

=cut
