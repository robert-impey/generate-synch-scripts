#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use Cwd qw(abs_path);

use GenerateSynchScripts qw(
generate_run_all_script
read_gss_file
);

my $has_Win32;
BEGIN {
    $has_Win32 = eval "use Win32; 1;"; 
}

my $man  = 0;
my $help = 0;

my ( $directory, $force_windows );

GetOptions(
    'help|?'        => \$help,
    'man'           => \$man,
    'directory|d=s' => \$directory,
    'windows!'      => \$force_windows
) or pod2usage(2);

pod2usage( -exitstatus => 0, -verbose => 2 ) unless ( $directory) ;
pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

if (not -d $directory) {
    warn "$directory is not a directory!\n";
    exit;
}

$directory = abs_path($directory);

my $windows;

if ( defined $force_windows ) {
    $windows = $force_windows;
}
else {
    $windows = $^O eq 'MSWin32';
}

if ($windows and not $has_Win32) {
    die "Windows scripts can't be created without the Win32 module!\n";
}

my ( $script_extension, $cd_command, $script_calling_command,
    $directory_separator, $pushd_command, $popd_command );
if ($windows) {
    $script_extension       = 'bat';
    $cd_command             = 'CD';
    $script_calling_command = 'CALL';
    $directory_separator    = '\\';
    $pushd_command          = 'PUSHD';
    $popd_command           = 'POPD';
}
else {
    $script_extension       = 'sh';
    $cd_command             = 'cd';
    $script_calling_command = '/bin/bash';
    $directory_separator    = '/';
    $pushd_command          = 'pushd';
    $popd_command           = 'popd';
}

my ($rsync_command, $container_directories_ref, $rsync_excluded_files_ref, $dirs_to_synch_ref) = read_gss_file($directory);
my %container_directories = %$container_directories_ref;
my %rsync_excluded_files = %$rsync_excluded_files_ref;
my @dirs_to_synch = @$dirs_to_synch_ref;

# Make the script to synch the rsync excluded files.

my $sef_script = "$directory/update-rsync-excluded.$script_extension";

unless ( -f $sef_script ) {
    open SEF, ">$sef_script";
    print SEF <<OUT;
    $rsync_command $rsync_excluded_files{local} $rsync_excluded_files{remote}
    $rsync_command $rsync_excluded_files{remote} $rsync_excluded_files{local}
OUT

    close SEF;

    chmod( 0755, $sef_script );
}

# Make the scripts for synching

for (qw/to from/) {
    my $direction        = $_;
    my $synch_script_dir = "$directory/$direction";
    mkdir $synch_script_dir unless -d $synch_script_dir;

    for my $dir_to_synch (@dirs_to_synch) {
        my $source      = $container_directories{'local'} . "/$dir_to_synch";
        my $destination = $container_directories{'remote'} . "/$dir_to_synch";

        if ( $direction eq 'from' ) {
            ( $source, $destination ) = ( $destination, $source );
        }

        my $synch_script = "$synch_script_dir/$dir_to_synch.$script_extension";

        unless ( -f $synch_script ) {
            open SYNCH, ">$synch_script" or die $!;
            print SYNCH
            "$rsync_command --exclude-from=$rsync_excluded_files{local} $source/ $destination";
            close SYNCH;

            chmod( 0755, $synch_script );
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

        chmod( 0755, $all_script );
    }
}

# Make the script for running everything
generate_run_all_script( $directory, $script_extension, $cd_command,
    $script_calling_command, $directory_separator, $windows, $pushd_command,
    $popd_command );

__END__

=head1 NAME

    generate-synch-scripts.pl - A program for generating scripts for synchronising directories using rsync.

=head1 SYNOPSIS

    generate-synch-scripts.pl -d [directory]
     Options:
       -help            brief help message
       -man             full documentation
       -directory|d		The directory in which to generate the scripts.
        --windows   Force Windows batch scripts.

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-directory|d>

Set the directory in which to generate the scripts.

=item B<-windows|w>

Force generating Windows batch scripts.

=back

=head1 DESCRIPTION

B<generate-synch-scripts.pl> looks in a directory for a file call gss.txt.

An example of such a file might be:

    rsync --progress -rvuztp 
    /Users/foo/rsync-excluded.txt
    Foo@remote:/cygdrive/Z/rsync-excluded.txt
    /Users/foo
    Foo@remote:/cygdrive/Z

    books
    music
    videos

The first line of the file is the rsync command that will be used to synch the directories.
The second and third lines contain the locations of the files that list the files to be excluded.
The third and fourth lines contain the top level directories that contain the directories that will be synched.

After the blank line, each line is for a directory in the top-level directory to be synched.

=cut
