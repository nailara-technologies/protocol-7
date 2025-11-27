## [:< ##

package AMOS7::Backup;    ###################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw|
    create_backup
    pack_backup
    restore_backup
    load_metadata
    save_metadata
    create_checksums
    check_path
    clean_dir
    create_dir
    timestamp_string
    load_source
    save_source
    $VERSION
|;

our $VERSION = qw| AMOS7::Backup-VERSION.ZK4M9P1 |;

##[ DEPENDENCIES ]############################################################

use Digest::BMW qw| bmw_256 |;
use Crypt::Misc qw| encode_b32r |;
use Cwd;

##[ GLOBAL STATE ]############################################################

our $verbose //= TRUE;    ## verbosity control ##
our $color   //= {};      ## color scheme (user must set) ##

##[ TIMESTAMP STRING ]########################################################

sub timestamp_string {
    my @t  = localtime( time() );
    my $_Y = 1900 + $t[5];
    my $_M = sprintf( qw| %02d |, ( $t[4] + 1 ) );
    my $_D = sprintf( qw| %02d |, $t[3] );
    my $_h = sprintf( qw| %02d |, $t[2] );
    my $_m = sprintf( qw| %02d |, $t[1] );
    my $_s = sprintf( qw| %02d |, $t[0] );

    return "$_Y-$_M-$_D" . '.' . "$_h:$_m:$_s";
}

##[ CHECK AND CREATE PATHS ]##################################################

sub check_path {
    my $_chk_path = shift;
    my $cut_path  = shift;

    $_chk_path =~ s,[^/]+$,,;

    my $current_path;

    foreach my $dir ( split( m|/+|, $_chk_path ) ) {
        $current_path .= '/' . $dir;
        $current_path =~ s,//,/,g;

        my $current_path_short = $current_path;

        if ( defined $cut_path ) {
            $current_path_short =~ s|^$cut_path||;
        }

        if ( !-d $current_path ) {
            if ( mkdir($current_path) ) {
                if ($verbose) {
                    print ": directory created : $current_path_short\n";
                }
            }
            else {
                die ":: cannot create directory '$current_path' : \l$OS_ERROR ::\n";
            }
        }
    }
}

sub create_dir {
    my $full_path = shift;
    my $parent_dir;
    my $new_dir;

    $full_path =~ s/\/$//;

    if ( $full_path =~ /^(.+)\/([^\/]+)$/ ) {
        ( $parent_dir, $new_dir ) = ( $1, $2 );
    }
    else {
        die
            ":: create_dir() : directory argument should include full path ::\n";
    }

    if ( !-d $parent_dir ) {
        die ":: create_dir() : parent directory '$parent_dir' does not exist ::\n";
    }

    if ( !-d $full_path ) {
        if ( mkdir($full_path) ) {
            if ($verbose) {
                print ": directory '$full_path' created :\n";
            }
            return TRUE;
        }
        else {
            die ":: cannot create directory '$full_path' : \l$OS_ERROR ::\n";
        }
    }
    else {
        if ($verbose) {
            print ": directory '$full_path' already exists :\n";
        }
        return FALSE;
    }
}

sub clean_dir {
    my $directory_path = shift;

    $directory_path =~ s,/$,,;

    if ( length( $directory_path // '' ) >= 5 and -d $directory_path ) {
        if ( !system( qw| rm -rf -- |, $directory_path ) ) {
            if ($verbose) {
                print ": directory removed : $directory_path\n";
            }
            return TRUE;
        }
        else {
            die ":: clean_dir() : removing directory '$directory_path' failed : \l$OS_ERROR ::\n";
        }
    }

    return FALSE;
}

##[ SOURCE CODE LOADING ]#####################################################

sub load_source {
    my $source_paths = shift;    # hashref of path name -> file list
    my %source;

    return \%source if not defined $source_paths;

    # Source_paths is expected to be a hashref from ncode's %targets
    # Example: { 'cfg' => [list of files], 'bin' => [list of files] }

    # For now, simple file loading. Caller provides file list.
    foreach my $filepath ( @{$source_paths} ) {
        next if -d $filepath;

        if ( -l $filepath ) {
            warn ":: skipping symlink '$filepath'\n";
            next;
        }

        local $RS = undef;
        open( my $FILE, '<', $filepath )
            or warn "cannot open file '$filepath' : \l$OS_ERROR\n" and next;

        $source{$filepath} = <$FILE>;
        close($FILE);
    }

    return \%source;
}

##[ SOURCE CODE SAVING ]######################################################

sub save_source {
    my $source_data = shift;
    my $cut_path    = shift;

    if ( ref($source_data) ne qw| HASH | ) {
        die 'source_data is not a hash reference';
    }

    my $change_count = 0;

    foreach my $file ( sort( keys %$source_data ) ) {

        check_path( $file, $cut_path );

        if ( defined $source_data->{$file} ) {

            open( my $FILE, '>', $file )
                or die ":: cannot open file '$file' : \l$OS_ERROR ::\n";
            print {$FILE} $source_data->{$file};
            close($FILE);
            $change_count++;

            if ($verbose) {
                my $bytes_written = length( $source_data->{$file} );
                print ": save file : "
                    . sprintf( '% 6d', $bytes_written )
                    . " bytes : $file\n";
            }
        }
    }

    if ( !$change_count ) {
        die ":: save_source() : no files changed, aborting ::\n";
    }

    return $change_count;
}

##[ CHECKSUM CREATION ]#######################################################

sub create_checksums {
    my $source_code = shift;
    my %file_checksums;

    return \%file_checksums if not defined $source_code;

    foreach my $file ( keys(%$source_code) ) {
        if ( defined $source_code->{$file} ) {

            $file_checksums{$file}
                = encode_b32r( bmw_256( $source_code->{$file} ) );

            if ($verbose) {
                print ': ' . $file_checksums{$file} . " : $file\n";
            }
        }
    }

    if ($verbose) {
        print "\n";
    }

    return \%file_checksums;
}

##[ METADATA MANAGEMENT ]#####################################################

sub save_metadata {
    my $file_name = shift;
    my $meta_data = shift;
    my $cut_path  = shift;
    my @file_data;

    if ( not defined $file_name or ref($meta_data) ne qw| HASH | ) {
        die ':: save_metadata() :: parameter error ::';
    }

    check_path($file_name);

    foreach my $first_key ( keys $meta_data->%* ) {
        my $file_key = $first_key;

        if ( ref( $meta_data->{$first_key} ) eq qw| HASH | ) {
            foreach my $second_key ( keys( %{ $meta_data->{$first_key} } ) ) {

                # swap key and value for bmw hashes
                if ( $first_key =~ m|bmw$| ) {
                    $file_key = $first_key . '.'
                        . $meta_data->{$first_key}{$second_key};
                    push( @file_data, "$file_key $second_key\n" );
                }
                else {
                    $file_key = $first_key . '.' . $second_key;
                    push( @file_data,
                        "$file_key " . $meta_data->{$first_key}{$second_key} . "\n" );
                }
            }
        }
        else {
            push( @file_data,
                "$file_key = " . $meta_data->{$first_key} . "\n" );
        }
    }

    if (@file_data) {
        if ( open( my $META_FILE, '>', $file_name ) ) {
            print {$META_FILE} sort(@file_data);
            close($META_FILE);

            if ($verbose) {
                my $file_name_short = $file_name;
                if ( defined $cut_path ) {
                    $file_name_short =~ s|^$cut_path||;
                }
                print ":: backup metadata saved to $file_name_short ::\n\n";
            }
        }
        else {
            die ":: cannot open backup metadata file '$file_name' : \l$OS_ERROR ::\n";
        }
    }
    else {
        die ':: save_metadata() :: nothing to save ::';
    }
}

sub load_metadata {
    my $file_name         = shift;
    my $cut_path          = shift;
    my $metadata_filename = '.backup.meta_data';
    my %meta_data;

    my @metadata_file;

    if ( $file_name =~ m{$metadata_filename$} ) {

        if ( !-f $file_name ) {
            die " :: expected metadata file '$file_name' does not exist ::\n";
        }

        open( my $META_FILE, '<', $file_name )
            or die " :: cannot open metadata file '$file_name' : \l$OS_ERROR ::\n";

        @metadata_file = <$META_FILE>;
        close($META_FILE);

    }
    elsif ( $file_name =~ m{backup\..+\.tar.gz$} ) {
        my $archive_content = qx| tar ztf $file_name |;

        # find the actual path of the metadata file in the archive
        foreach my $archive_content_file (
            sort( split( /\n/, $archive_content ) ) ) {
            if ( $archive_content_file =~ m|$metadata_filename$| ) {
                $metadata_filename = $archive_content_file;
                last;
            }
        }

        my $file_contents = qx| tar zxf $file_name $metadata_filename -O |;
        @metadata_file = split( m|\n|, $file_contents );
    }
    else {
        die ":: load_metadata() : unsupported file format for '$file_name' ::\n";
    }

    foreach my $data_line (@metadata_file) {
        chomp($data_line);

        if ( $data_line =~ m|^([^\.]+)\s(.*)$| ) {
            $meta_data{$1} = $2;
        }
        elsif ( $data_line =~ m|^([^\.]+)\.([^\.]+)\s(.*)$| ) {
            $meta_data{$1}{$2} = $3;
        }
        else {
            die " :: invalid syntax in meta data file : '$data_line' ::\n";
        }
    }

    if ( not keys %meta_data ) {
        die " :: meta data file '$file_name' was empty ::\n";
    }

    return \%meta_data;
}

##[ BACKUP PACKING ]##########################################################

sub pack_backup {
    my $backup_dir  = shift;
    my $backup_file = shift;
    my $cut_path    = shift;
    my $pack_dir    = shift // ($ENV{'HOME'} . '/.code/current_backup/');

    if ($verbose) {
        my $backup_file_short = $backup_file;
        if ( defined $cut_path ) {
            $backup_file_short =~ s|^$cut_path||;
        }
        print ":: creating backup archive file $backup_file_short ::\n\n";
    }

    my $current_dir = Cwd::getcwd();
    chdir($pack_dir) or die ":: cannot change to $pack_dir : \l$OS_ERROR ::\n";

    my $pack_results = qx| tar czvvf $backup_file . |;
    chmod( 0400, $backup_file );

    chdir($current_dir)
        or die ":: cannot change back to $current_dir : \l$OS_ERROR ::\n";

    if ($verbose) {
        my $line_count = split( /\n/, $pack_results );
        print ":: packed $line_count items ::\n\n";
    }

    return $backup_file;
}

##[ MAIN BACKUP CREATION ]####################################################

sub create_backup {
    my $backup_source = shift;    # the sourcecode hash of files to be backed up
    my $backup_metadata = shift;  # hashref to metadata
    my $modified_source = shift;  # modified source [if exists]
    my $work_path = shift // ($ENV{'HOME'} . '/.code/');

    die "first argument to create_backup() expected a hash reference"
        if ref($backup_source) ne qw| HASH |;
    die "second argument to create_backup() expected a hash reference"
        if ref($backup_metadata) ne qw| HASH |;

    if ($verbose) {
        print ":: creating backup of original files ::\n\n";
    }

    # Make sure we have backup directory
    my $backup_dir = $work_path . 'backups/';
    check_path($backup_dir);

    my $pack_dir = $work_path . 'current_backup/';
    clean_dir($pack_dir);

    # Make a copy of the sourcecode in current_backup dir
    save_source( _add_path( $pack_dir, $backup_source ), $pack_dir );

    print "\n" if $verbose;

    # Prepare metadata
    my $metadata_file = $pack_dir . '.backup.meta_data';

    $backup_metadata->{'backup'}{'time'} = time();

    chomp( my $username = $ENV{'USER'} || qx| whoami | );
    if ( defined $username ) {
        $backup_metadata->{'backup'}{'created_by'} = $username;
    }

    chomp( my $hostname = $ENV{'HOSTNAME'} || qx| hostname | );
    if ( defined $hostname ) {
        $backup_metadata->{'backup'}{'created_on'} = $hostname;
    }

    if ($verbose) {
        print ":: calculating backup checksums ::\n\n";
    }

    # Add checksums of original source
    if ( ref($modified_source) eq qw| HASH | ) {
        $backup_metadata->{'original_bmw'}
            = create_checksums($backup_source);
    }

    if ($verbose) {
        print ":: calculating modification checksums ::\n\n";
    }

    # Add checksums of modified source
    if ( ref($modified_source) eq qw| HASH | ) {
        $backup_metadata->{'modified_bmw'}
            = create_checksums($modified_source);
    }

    save_metadata( $metadata_file, $backup_metadata, $work_path );

    my $operation_type = '';
    if ( defined $backup_metadata->{'operation'}{'type'} ) {
        $operation_type = $backup_metadata->{'operation'}{'type'} . '.';
    }

    my $backup_file;
    while ( not defined $backup_file or -f $backup_dir . $backup_file ) {
        if ( defined $backup_file and -f $backup_dir . $backup_file ) {
            sleep 1;
        }

        $backup_file = 'backup.' . $operation_type . &timestamp_string . '.tar.gz';
    }

    pack_backup( $backup_dir, $backup_dir . $backup_file, $work_path, $pack_dir );

    clean_dir($pack_dir);

    return $backup_dir . $backup_file;
}

##[ BACKUP RESTORATION ]######################################################

sub restore_backup {
    my $backup_file = shift;
    my $target_root = shift;

    if ( !-f $backup_file ) {
        die sprintf " :: backup file '%s' does not exist ::\n", $backup_file;
    }

    if ($verbose) {
        print ":: restoring from backup '$backup_file' ::\n\n";
    }

    # Create temp directory for extraction
    my $temp_dir = $target_root . 'restore_temp_' . time();
    mkdir($temp_dir) or die ":: cannot create temp directory : \l$OS_ERROR ::\n";

    # Determine archive type and extract
    my $extract_cmd = $backup_file =~ /\.tar\.xz$/
        ? "cd $temp_dir && tar -xJf $backup_file"
        : "cd $temp_dir && tar -xzf $backup_file";

    if ( system($extract_cmd) != 0 ) {
        system("rm -rf $temp_dir");
        die ":: backup extraction failed ::\n";
    }

    # Verify archive structure
    if ( !-d "$temp_dir/configuration" ) {
        system("rm -rf $temp_dir");
        die " :: invalid backup archive - missing configuration dir ::\n";
    }

    # Restore files
    system("cp -r $temp_dir/configuration/* $target_root/configuration/");

    if ($verbose) {
        print ":: backup restored successfully ::\n";
    }

    system("rm -rf $temp_dir");

    return TRUE;
}

##[ HELPER FUNCTIONS ]########################################################

sub _add_path {
    my $prefix  = shift;
    my $file_hash = shift;
    my $new_hash = {};

    foreach my $filepath ( keys %$file_hash ) {
        my $newpath = $prefix . $filepath;
        $newpath =~ s|//|/|g;
        $new_hash->{$newpath} = $file_hash->{$filepath};
    }

    return $new_hash;
}

##[ END OF MODULE ]###########################################################

1;

#,,,.,.,,,...,,,,,...,...,,..,.,.,.,,,...,,,,,..,,...,...,,,.,...,,.,,,,.,,.,,
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_1
#\\\|PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_2
#\[7]PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE_3
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
