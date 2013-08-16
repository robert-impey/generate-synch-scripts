package GenerateSynchScripts;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(
  generate_run_all_script
);

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
