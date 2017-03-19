package GenerateSynchScripts;

use strict;
use warnings;

BEGIN {
    eval "use Win32; 1;";
}

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

    my $directory_in_script = get_directory_in_script($directory, $windows);

    my $all_script = "$directory/all.$script_extension";
    unless ( -f $all_script ) {
        open ALL, ">$all_script";
        print ALL <<OUT;
$pushd_command "$directory_in_script"
$script_calling_command update-rsync-excluded.$script_extension
$cd_command to
$script_calling_command all.$script_extension
$cd_command ..${directory_separator}from
$script_calling_command all.$script_extension
$cd_command ..
$popd_command
OUT

        close ALL;

        chmod( 0755, $all_script );
    }
}

sub get_directory_in_script {
    my $directory = shift;
    my $windows = shift;

    if ($windows) {
        my $cygdrive_letter = undef;
        if ($directory =~ m{/cygdrive/([a-zA-Z])(.+)}) {
            $cygdrive_letter = $1;
            $directory = $2;
        }

        my $windowsDirectory = Win32::GetFullPathName($directory);

        if (defined($cygdrive_letter)) {
            $cygdrive_letter = uc($cygdrive_letter);
            $windowsDirectory =~ s/^[a-zA-Z]/$cygdrive_letter/;
        }
        
        return $windowsDirectory;
    } else {
        return $directory;
    }
}

1;
