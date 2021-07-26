#!/usr/bin/env perl

=pod

=head1 NAME

sync_datamodeler_config.pl - Backup or restore the (global) Oracle SQL Developer Data Modeler configuration.

=head1 SYNOPSIS

  sync_datamodeler_config.pl [OPTION...] [DATAMODELER_HOME...]

=head1 DESCRIPTION

This utility saves and restores the global Oracle SQL Developer Data Modeler configuration. Currently only XML files are saved and thus restored.

On the command line you can specify zero or more datamodeler installation
homes (zero for the Mac OS X since
/Applications/OracleDataModeler.app/Contents/Resources/datamodeler is the installation
home, else at least one). For each installation home you should find the file
datamodeler/bin/version.properties with a line like:

  VER_FULL=18.4.0.339.1532

This version is used in the folders where a part of the configuration is stored:

=over 4

=item Windows user configuration

%APPDATA%/Oracle SQL Developer Data Modeler/system18.4.0.339.1532

=item Mac OS X user configuration

$HOME/.oraclesqldeveloperdatamodeler/system18.4.0.339.1532

=item Installation home configuration

datamodeler/types

=back

=head1 OPTIONS

=over 4

=item B<--help>

This help.

=item B<--backup>

Perform a backup. Files are stored in the config directory as specified by the
command line option. You can not restore at the same time.

=item B<--config-directory>

The directory to backup to or restore from. Mandatory.

=item B<--config-version>

The configuration version to use instead of the installation home version. Useful when upgrading Data Modeler where you want to use the old Data Modeler version as the configuration version to restore from.

=item B<--restore>

Perform a restore from the config directory as specified by the
command line option. You can not backup at the same time.

=item B<--verbose>

Increase verbose logging. Defaults to 0.

=back

=head1 NOTES

=head1 EXAMPLES

When you upgrade Data Modeler, the tool asks whether to import settings from a previous version. However it seems to forget settings like Custom Transformation Scripts. Therefore backup first the old version, next install the new version and then restore the old settings using this script.

This example is from my Mac OS X, where the installation home is fixed.

Backup (old version is 18.4.0.339.1532) using this command:

  $ perl sync_datamodeler_config.pl --config-directory /tmp --backup

After installing the new Data Modeler version, restore the old settings using this command:

  $ perl sync_datamodeler_config.pl --config-directory /tmp --config-version 18.4.0.339.1532 --restore

=head1 BUGS

=head1 SEE ALSO

=head1 AUTHOR

Gert-Jan Paulissen.

=head1 VERSION

$Header$

=head1 HISTORY

2019-08-29  G.J. Paulissen

First version.

2020-04-02  G.J. Paulissen

Second version where the directory to backup to or restore from needs to be
specified.

2021-07-26  G.J. Paulissen

Third version where the configuration version can be specified and where the installation home for a Mac need not be specified.

=cut

use 5.008; # Perl 5.8 should be OK

# use autodie; # automatically die when a system call gives an error (for example open)
use strict;
use warnings;

use File::Basename;
use lib &dirname($0); # to find File::Copy::Recursive in this directory
use File::Copy::Recursive qw(dircopy);
use File::Find;
use File::Path qw(remove_tree);
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use Env qw(HOME APPDATA);

# VARIABLES

my $program = &basename($0);

# command line options

my $config_directory = undef;
my $config_version = undef;
my $backup = 0;
my $restore = 0;
my $verbose = 0;
my $version_config = undef;

my $datamodeler_home;

# PROTOTYPES

sub main ();
sub process_command_line ();
sub process ($);
sub get_version ($);
sub config_cleanup ($);
                                                         
# MAIN

main();

# SUBROUTINES

sub main () 
{
    process_command_line();
    
    map { process($_) } @ARGV;
}

sub process_command_line ()
{
    # Windows FTYPE and ASSOC cause the command 'generate_ddl -h -c file'
    # to have ARGV[0] == ' -h -c file' and number of arguments 1.
    # Hence strip the spaces from $ARGV[0] and recreate @ARGV.
    if ( @ARGV == 1 && $ARGV[0] =~ s/^\s+//o ) {
        @ARGV = split( / /, $ARGV[0] );
    }
    
    my @argv;
    
    foreach my $arg (@ARGV) {
        foreach (glob($arg)) {
            push(@argv, qq{$_});
        }
    }

    @ARGV = @argv;
    
    Getopt::Long::Configure(qw(require_order));

    #
    GetOptions('help' => sub { pod2usage(-verbose => 2) },
               'backup' => \$backup,
               'config-directory:s' => \$config_directory,
               'config-version:s' => \$config_version,
               'restore' => \$restore,
               'verbose+' => \$verbose
        )
        or pod2usage(-verbose => 0);

    #
    if ($^O eq 'darwin') {
        pod2usage(-message => "$0: Should NOT supply an Oracle SQL Developer Data Modeler home on Mac OS X. Run with --help option.\n")
            unless @ARGV == 0;
        push(@ARGV, '/Applications/OracleDataModeler.app/Contents/Resources/datamodeler');
    } else {
        pod2usage(-message => "$0: Must supply at least one Oracle SQL Developer Data Modeler home. Run with --help option.\n")
            unless @ARGV >= 1;
    }

    pod2usage(-message => "$0: The config directory must exist and be writable. Run with --help option.\n")
        unless defined($config_directory) && -d $config_directory && -w $config_directory;
    
    pod2usage(-message => "$0: Must either backup or restore but not both. Run with --help option.\n")
        unless $backup + $restore == 1;

    foreach my $datamodeler_home (@ARGV) {
        my $version = undef;
        
        eval {
            $version = get_version($datamodeler_home);
        };

        warn $@
            if ($@);
        
        pod2usage(-message => "$0: Can not read version for installation home '$datamodeler_home'. Run with --help option.\n") 
            unless (defined($version));
    }
}

sub process ($)
{
    my $datamodeler_home = $_[0];
    my $version = get_version($datamodeler_home);
    my $user_config = ($^O eq 'MSWin32' ? File::Spec->catdir($APPDATA, 'Oracle SQL Developer Data Modeler') : File::Spec->catdir($HOME, '.oraclesqldeveloperdatamodeler'));
    my @dirs;
    my $operation = ($backup ? "Backup" : "Restore");

    print STDOUT "\n*** $operation $datamodeler_home ***\n"
        if ($verbose);

    push(@dirs, [ File::Spec->catdir($datamodeler_home, 'datamodeler', 'types'), File::Spec->catdir($config_directory, (defined($config_version) ? $config_version : $version), 'datamodeler', 'types') ]);
    push(@dirs, [ File::Spec->catdir($user_config, "system$version"), File::Spec->catdir($config_directory, (defined($config_version) ? $config_version : $version), 'system') ]);

    foreach my $dirs (@dirs) {
        my ($dir1, $dir2) = @$dirs;
        
        my $from = ($backup ? $dir1 : $dir2);
        my $to = ($backup ? $dir2 : $dir1);
        
        print STDOUT "$operation from '$from' to '$to'\n"
            if ($verbose);

        dircopy($from, $to);
        # do not clutter the source code repository with irrelevant files and empty directories
        config_cleanup($to)
            if ($backup);
    }
}

sub get_version ($)
{
    my $datamodeler_home = $_[0];    
    my $file = File::Spec->catfile($datamodeler_home, 'datamodeler', 'bin', 'version.properties');

    open(my $fh, '<', $file) || die "Can not open $file: $!";

    my %hash;
    
    while (<$fh>)
    {
        chomp;

        my ($key, $val) = split /=/;
        
        $hash{$key} = $val
            if (defined($key));

        last
            if (defined($key) && $key eq 'VER_FULL');
    }

    close $fh || die "Can not close $file: $!";

    print STDOUT "*** Version from $file: ", $hash{VER_FULL}, " ***\n"
        if ($verbose);    

    return $hash{VER_FULL};
}

sub config_cleanup ($) {
    my $dir = $_[0];
    my @file_list;
    my $rs = sub {
        push(@file_list, $File::Find::name)
            if (-f && !(m/\.(xml)$/)); # only keep xml files
    };

    print STDOUT "\n*** cleanup config directory $dir ***\n"
        if ($verbose);

    find($rs, $dir);

    unlink @file_list;

    my @dir_list;
    $rs = sub {
        push(@dir_list, $File::Find::name)
            if (-d && (m/^system_cache/)); # remove system_cache directories
    };
    
    find($rs, $dir);

    remove_tree(@dir_list, { verbose => $verbose });

    # Remove empty directories.
    # Use eval to ignore errors due to $_ being a file, the current directory (.) or not empty.
    finddepth(sub { eval { rmdir }; }, $dir);
}
