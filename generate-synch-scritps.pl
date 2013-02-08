#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

my $man  = 0;
my $help = 0;

my ($directory);

GetOptions(
	'help|?'        => \$help,
	'man'           => \$man,
	'directory|d=s' => \$directory
  )
  or pod2usage(2);

my $windows = $^O eq 'MSWin32';

my (
	$script_extension,       $cd_command,
	$script_calling_command, $directory_separator
);
if ($windows) {
	$script_extension       = 'bat';
	$cd_command             = 'CD';
	$script_calling_command = 'CALL';
	$directory_separator    = '\\';
}
else {
	$script_extension       = 'sh';
	$cd_command             = 'cd';
	$script_calling_command = '/bin/bash';
	$directory_separator    = '/';
}

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

open DIRS, "<$directory/gss.txt" or die $!;
my @directories_file_lines = <DIRS>;
close DIRS;
chomp @directories_file_lines;

my ( %container_directories, %rsync_excluded_files );
my $rsync_command;
(
	$rsync_command,                $rsync_excluded_files{local},
	$rsync_excluded_files{remote}, $container_directories{local},
	$container_directories{remote}
  )
  = @directories_file_lines[ 0 .. 4 ];
my @dirs_to_synch;

for ( 6 .. $#directories_file_lines ) {
	push @dirs_to_synch, $directories_file_lines[$_];
}

# Make the script to synch the rsync excluded files.

my $sef_script = "$directory/update-rsync-excluded.$script_extension";

unless ( -f $sef_script ) {
	open SEF, ">$sef_script";
	print SEF <<OUT;
$rsync_command $rsync_excluded_files{local} $rsync_excluded_files{remote}
$rsync_command $rsync_excluded_files{remote} $rsync_excluded_files{local}
OUT

	close SEF;

	chmod( 0755, $sef_script ) unless $windows;
}

# Make the scripts for synching

for (qw/from to/) {
	my $direction        = $_;
	my $synch_script_dir = "$directory/$direction";
	mkdir $synch_script_dir unless -d $synch_script_dir;

	for my $dir_to_synch (@dirs_to_synch) {
		my $source      = $container_directories{local} . "/$dir_to_synch";
		my $destination = $container_directories{remote} . "/$dir_to_synch";

		if ( $direction eq 'from' ) {
			( $source, $destination ) = ( $destination, $source );
		}

		my $synch_script = "$synch_script_dir/$dir_to_synch.$script_extension";

		unless ( -f $synch_script ) {
			open SYNCH, ">$synch_script" or die $!;
			print SYNCH
"$rsync_command --exclude-from=$rsync_excluded_files{local} $source/ $destination";
			close SYNCH;

			chmod( 0755, $synch_script ) unless $windows;
		}
	}

	my $all_script = "$synch_script_dir/all.$script_extension";
	unless ( -f $all_script ) {
		open ALL, ">$all_script";
		for my $dir_to_synch (@dirs_to_synch) {
			print ALL
			  "$script_calling_command $dir_to_synch.$script_extension\n";
		}
		close ALL;

		chmod( 0755, $all_script ) unless $windows;
	}
}

# Make the script for running everything
my $all_script = "$directory/all.$script_extension";
unless ( -f $all_script ) {
	open ALL, ">$all_script";
	print ALL <<OUT;
$cd_command "$directory"
$script_calling_command update-rsync-excluded.$script_extension
$cd_command to
$script_calling_command all.$script_extension
$cd_command ..${directory_separator}from
$script_calling_command all.$script_extension
$cd_command ..
OUT

	close ALL;

	chmod( 0755, $all_script ) unless $windows;
}

__END__

=head1 NAME

    generate-synch-scripts.pl - A program for generating scripts for synchronising directories using rsync.

=head1 SYNOPSIS

    generate-synch-scripts.pl -d [directory]
     Options:
       -help            brief help message
       -man             full documentation
       -directory|d		The directory in which to generate the scripts.

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-directory|d>

Set the directory in which to generate the scripts.

=back

=head1 DESCRIPTION

B<generate-synch-scripts.pl> looks in a directory for a file call gss.txt.

An example of such a file might be:

	rsync --progress -rvuztp 
	/cygdrive/V/rsync-excluded.txt
	/cygdrive/W/rsync-excluded.txt
	/cygdrive/V
	/cygdrive/W
	
	videos
	music
	books

The first line of the file is the rsync command that will be used to synch the directories.
The second and third lines contain the locations of the files that list the files to be excluded.
The third and fourth lines contain the top level directories that contain the directories that will be synched.

After the blank line, each line is for a directory in the top-level directory to be synched.

=cut
