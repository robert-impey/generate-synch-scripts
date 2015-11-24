package GenerateSynchScripts;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(
generate_run_all_script
read_gss_file
);

sub read_gss_file
{
    my $directory = shift;

    open DIRS, "<$directory/gss.txt" or die $!;
    my @directories_file_lines = <DIRS>;
    close DIRS;
    chomp @directories_file_lines;

    my ( %container_directories, %rsync_excluded_files );
    my $rsync_command;
    (
        $rsync_command,                  
        $rsync_excluded_files{'local'},
        $rsync_excluded_files{'remote'}, 
        $container_directories{'local'},
        $container_directories{'remote'}
    ) = @directories_file_lines[ 0 .. 4 ];

    my @dirs_to_synch;
    for ( 6 .. $#directories_file_lines ) {
        my $directories_file_line = $directories_file_lines[$_];
        unless ( $directories_file_line =~ /^\s*$/ ) {
            push @dirs_to_synch, $directories_file_lines[$_];
        }
    }

    return ($rsync_command, \%container_directories, \%rsync_excluded_files, \@dirs_to_synch);
}

sub generate_run_all_script {
    my ( $directory, $script_extension, $cd_command, $script_calling_command,
        $directory_separator, $windows, $pushd_command, $popd_command )
    = @_;

    my $all_script = "$directory/all.$script_extension";
    unless ( -f $all_script ) {
        open ALL, ">$all_script";
        print ALL <<OUT;
$pushd_command "$directory"
$script_calling_command update-rsync-excluded.$script_extension
$cd_command to
$script_calling_command all.$script_extension
$cd_command ..${directory_separator}from
$script_calling_command all.$script_extension
$cd_command ..
$popd_command
OUT

        close ALL;

        chmod( 0755, $all_script ) unless $windows;
    }
}

1;
