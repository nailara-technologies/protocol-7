## [:< ##

package AMOS7::FILE;    ######################################################

use v5.24;
use strict;
use English;
use warnings;
use Exporter;
##[ abs_path ]##
use Cwd;
use File::stat;
use File::Spec::Functions qw| catfile catdir |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7;

use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

my $VERSION = qw| AMOS7::FILE-VERSION.4HI7Z2Q |;

@EXPORT = qw| create_dir_path |;

@EXPORT_OK = qw[

    get_homepath
    directory_owner
    file_path_perms
    resolved_path_abs
    last_existing_directory
    append_timestamped_multiline
    read_all_timestamped_multiline
    read_timestamped_multiline_recent

];

my $usrname_re = qr|^[0-9A-Za-z][0-9A-Za-z\-_]{0,31}$|
    ;    ## Match base.regex usr_str_re (max 32 chars)

##[ DIRECTORY PATH CREATION ]#################################################

sub create_dir_path {

    ##  owner and group are optional  ##  names not ids  ##
    ##
    my ( $path, $param_mode, $param_owner, $owner_group ) = @ARG;

    $param_mode //= 0700;    # <-- strict default
    $param_mode = oct($param_mode) if $param_mode =~ m|^0|;
    if ( not defined $path ) {
        warn_err('expected defined path <{C1}>');
        return undef;
    } elsif ( $path !~ m|^/[^/]+| ) {
        return warn 'expected absolute path [ to create ] <{C1}>';
        return undef;
    }

    my $mkdir_umask = 0777 & ~0777;    ## <-- permissive setting.., ##
    my $previous_umask;

    ## optionally recursive mode array [ref] ## expand [owners] [LLL]
    my $modes = ref $param_mode ne qw| ARRAY | ? [$param_mode] : $param_mode;

    ### path clean-up ####
    $path =~ s|/[^/]+/\.\./||g;
    $path =~ s|//|/|g;
    $path =~ s|/$||;

    if ( $path !~ m|^/[^/]+| ) {
        warn_err( "path not valid : '%s'", 1, $path );
        return undef;
    }

    ## reading optional parameters ##
    my ( $uid, $gid );
    if ( defined $param_owner ) {

        if ( $param_owner eq qw| :parent: | ) {    ##  parent path owner  ##

            my $last_dirpath = last_existing_directory($path);
            $param_owner = directory_owner($last_dirpath);
        }

        if ( $param_owner !~ $usrname_re ) {
            warn_err( "specified username ['%s'] not valid", 1,
                $param_owner );
            return undef;
        }
        ( undef, undef, $uid, $gid ) = getpwnam($param_owner);
        if ( not defined $uid ) {
            warn_err( "owner %s not in passwd file", 1, $param_owner );
            return undef;
        }
    }
    if ( defined $owner_group ) {
        if ( not defined $param_owner ) {
            warn_err(
                'the group parameter also requires owner to be defined <{C1}>'
            );
            return undef;
        }
        if ( $owner_group !~ $usrname_re ) {
            warn_err( "specified group name not valid ['%s']",
                1, $param_owner );
            return undef;
        }
        my $optional_gid = getgrnam($owner_group);
        if ( not defined $optional_gid ) {
            warn_err( 'requested group %s not in passwd file',
                1, $owner_group );
            return undef;
        } else {
            $gid = $optional_gid;
        }
    }

    if ( -d $path ) {    ##  checking existing path attributes  ##

        ## check permissions of existing directory .., ##
        my $current_perms = file_path_perms($path);

        if ( $current_perms ne sprintf '%#o', $param_mode ) {
            if ( not chmod( $param_mode, $path ) ) {
                warn_err( 'chmod[ %s ] : %s', 1, $path, lcfirst($OS_ERROR) );
                return undef;
            }
        }

        ## check ownership of already present directory ##
        if ( defined $param_owner ) {
            ( my $current_uid, my $current_gid ) = directory_owner($path);

            if ( $current_uid != $uid or $current_gid != $gid ) {
                my $correction_str = sprintf 'uid %d, gid %d', $uid, $gid;
                $correction_str = sprintf 'uid %d', $uid
                    if $current_gid == $gid;
                $correction_str = sprintf 'gid %d', $gid
                    if $current_uid == $uid;
                if ( not chown( $uid, $gid, $path ) ) {
                    warn_err( 'chown [%d:%d] %s : [ %s ]',
                        1, $uid, $gid, $path, lcfirst($OS_ERROR) );
                    return undef;
                }
            }
        }
        return $path;    ##  is as configured  ##
    }

    ##  recursively creating specified path  ##

    my $current_mode;
    my $current_path = '';
    $previous_umask = umask($mkdir_umask);

    if ( umask != $mkdir_umask ) {
        warn_err( "umask[ %s ] : [ still %u ] mkdir aborted ..,",
            1, $mkdir_umask, umask );
        return undef;
    }

    foreach my $_dir ( split qw| / |, $path ) {
        next if not length $_dir;

        $current_path .= sprintf qw| /%s |, $_dir;
        $current_mode //= shift $modes->@*;

        next if -d $current_path;    ## <-- exists \ continue ., ##

        if ( not mkdir( $current_path, $current_mode ) ) {
            warn_err( 'mkdir[ %s ] : [ %s ]',
                1, $current_path, lcfirst($OS_ERROR) );
            return undef;
        }

        $current_mode = oct $current_mode if $current_mode =~ m|^0|;

        if ( not chmod( $current_mode, $current_path ) ) {
            warn_err( 'chmod[ %04o ] : [ %s ] <{C1}>',
                1, $param_mode, lcfirst($OS_ERROR) );
            warn_err( 'removing %s [ chmod failed ]', 1, $path );
            if ( not unlink($path) ) {
                warn_err( 'unlink[ %s ] : ', 1, lcfirst($OS_ERROR) );
            }
            return undef;
        }

        if ( defined $param_owner ) {
            if ( not chown( $uid, $gid, $current_path ) ) {
                warn_err( 'chown [%d:%d] %s : [ %s ]',
                    1, $uid, $gid, $current_path, lcfirst($OS_ERROR) );
                warn_err( 'removing %s [ chown failed ]', 1, $path );
                if ( not unlink($path) ) {
                    warn_err( 'unlink[ %s ] : ', lcfirst($OS_ERROR) );
                }
                return undef;
            }
        }
    }
    umask $previous_umask if defined $previous_umask;

    return $path;
}

##[ PATH STAT ROUTINES ]#####################################################

sub last_existing_directory {    ## returns last parent that still exists ##

    my $check_path = shift // '';

    if ( not length $check_path ) {
        warn_err('expected [ absolute ] path argument <{C1}>');
        return undef;
    }
    return $check_path if -d $check_path;
    return undef       if index( $check_path, qw| / |, 0 ) != 0;
    ( my $last_dirpath = $check_path ) =~ s|((*plb:.)/)?[^/]+$||;
    my $last_path_len = length $last_dirpath;
    while ( not -d $last_dirpath ) {
        $last_dirpath =~ s|((*plb:.)/)?[^/]+$||;
        return undef if length $last_dirpath == $last_path_len;
        my $last_path_len = length $last_dirpath;
    }
    return $last_dirpath;
}

sub directory_owner {

    my $chk_path = shift;

    if ( not defined $chk_path or not length $chk_path ) {
        warn_err 'path param expected <{C1}>';
        return undef;
    } elsif ( not -e $chk_path ) {
        warn_err( "path not found [ '%s' ]", 1, $chk_path );
    }

    my $stat_result = File::stat::stat($chk_path);

    ##  returning uid, gid in list context  ##
    return ( $stat_result->uid, $stat_result->gid ) if wantarray;

    ## return resolved username in scalar context ##
    my $username = getpwuid( $stat_result->uid );
    if ( not defined $username ) {
        warn_err( 'cannot resolve uid %d in passwd file',
            1, $stat_result->uid );
        return undef;
    } else {
        return $username;
    }
}

sub file_path_perms {

    my $chkpath_abs = resolved_path_abs( shift, 1 );

    return undef if not defined $chkpath_abs;

    return sprintf '%#o', File::stat::stat($chkpath_abs)->mode & 07777;
}

sub get_homepath {

    my $user    = shift // $ENV{'USER'} // $ENV{'LOGNAME'} // '';
    my $homedir = $ENV{'HOME'} // $ENV{'LOGDIR'} // '';

    return $homedir if length $homedir and -d $homedir;

    if ( $user eq '' ) {
        $user = getpwuid($EUID);    # current user[id]
    } elsif ( $user =~ m|^\d+$| ) {
        $user = getpwuid($user);    # given by uid
    }    # else provided as name .,

    my @pwnam = getpwnam($user);
    $homedir = $pwnam[7];

    if ( @pwnam == 0 ) {
        warn_err( "<< no such user : '%s' >>", 1, $user );
    } elsif ( not length $homedir ) {
        warn_err( "<< empty home directory path : user '%s' >>", 1, $user );
    }

    return $homedir;
}

sub resolved_path_abs {

    my $chk_path     = shift;
    my $caller_level = shift || 0;

    if ( $caller_level !~ m|^\d+$| ) {
        warn_err('caller level not valid <{C1}>');
    }
    my $caller_level_str = sprintf ' <{C%d}>', $caller_level + 1;

    if ( not defined $chk_path or not length $chk_path ) {
        warn_err( 'path param expected' . $caller_level_str );
        return undef;
    }

    my $chkpath_abs = Cwd::abs_path($chk_path);

    ## broken links and circular references ##
    ##
    if ( -l $chk_path and not length $chkpath_abs ) {
        warn_err( "symlink err [ '%s' ]", $caller_level + 1, $chk_path );
        return undef;
    } elsif ( not length $chkpath_abs ) {
        warn_err( "path not found [ '%s' ]", $caller_level + 1, $chk_path );
        return undef;
    }

    return $chkpath_abs;
}

##[ MULTILINE TIMESTAMPED ENTRIES ]############################################

sub append_timestamped_multiline {

    my $filename = shift;
    my @lines    = @ARG;

    warn_err('filename required for timestamped multiline append <{C1}>')
        and return undef
        if not defined $filename or not length $filename;

    warn_err('at least one line required for multiline append <{C1}>')
        and return undef
        if not @lines;

    ## Get current network time - need to call it from main scope
    my $network_time
        = defined $main::code{'base.ntime.b32'}
        ? $main::code{'base.ntime.b32'}->(3)
        : time();

    ## Construct entry: timestamp, line count, then all lines
    my $line_count = scalar @lines;
    my $entry      = sprintf "%s %d\n", $network_time, $line_count;
    $entry .= join "\n", @lines;
    $entry .= "\n";

    ## Resolve file path
    my $file_path;
    if ( $filename =~ m|/| ) {
        $file_path = $filename;
    } else {
        my $homedir = get_homepath();
        if ( not defined $homedir ) {
            warn_err(
                'cannot determine home directory for history file <{C1}>');
            return undef;
        }
        my $history_dir = catfile( $homedir, '.n' );
        if ( not -d $history_dir ) {
            if ( not mkdir( $history_dir, 0700 ) ) {
                warn_err( 'cannot create history directory %s [ %s ]',
                    1, $history_dir, lcfirst($OS_ERROR) );
                return undef;
            }
        }
        $file_path = catfile( $history_dir, $filename );
    }

    ## Append to file
    my $fh;
    if ( not open( $fh, '>>', $file_path ) ) {
        warn_err( 'cannot open history file for append %s [ %s ]',
            1, $file_path, lcfirst($OS_ERROR) );
        return undef;
    }

    if ( not print {$fh} $entry ) {
        warn_err( 'cannot write to history file %s [ %s ]',
            1, $file_path, lcfirst($OS_ERROR) );
        close($fh);
        return undef;
    }

    close($fh)
        or warn_err( 'cannot close history file %s [ %s ]',
        1, $file_path, lcfirst($OS_ERROR) );

    return $network_time;
}

sub read_all_timestamped_multiline {

    my $filename = shift;

    warn_err('filename required for read multiline <{C1}>') and return undef
        if not defined $filename or not length $filename;

    ## Resolve file path
    my $file_path;
    if ( $filename =~ m|/| ) {
        $file_path = $filename;
    } else {
        my $homedir = get_homepath();
        if ( not defined $homedir ) {
            warn_err(
                'cannot determine home directory for history file <{C1}>');
            return undef;
        }
        $file_path = catfile( $homedir, '.n', $filename );
    }

    return undef if not -e $file_path;

    ## Read entire file
    my $file_content;
    my $fh;
    if ( not open( $fh, '<', $file_path ) ) {
        warn_err( 'cannot open history file %s [ %s ]',
            1, $file_path, lcfirst($OS_ERROR) );
        return undef;
    }

    $file_content = do { local $/; <$fh> };
    close($fh) or warn_err( 'cannot close history file %s', 1, $file_path );

    return undef if not defined $file_content;

    ## Parse entries: timestamp linecount
    my @entries = ();
    my $pos     = 0;

    while ( $pos < length($file_content) ) {
        ## Parse header line: "timestamp linecount\n"
        my $header_end = index( $file_content, "\n", $pos );
        last if $header_end < 0;

        my $header = substr( $file_content, $pos, $header_end - $pos );
        my ( $timestamp, $line_count ) = split ' ', $header;

        if ( not defined $timestamp or not defined $line_count ) {
            warn_err( 'invalid history entry header at position %d <{C1}>',
                1, $pos );
            last;
        }

        $pos = $header_end + 1;

        ## Read line_count lines
        my @entry_lines = ();
        for ( 1 .. $line_count ) {
            my $next_newline = index( $file_content, "\n", $pos );
            if ( $next_newline < 0 ) {
                ## Unexpected EOF, read to end
                push @entry_lines, substr( $file_content, $pos );
                $pos = length($file_content);
                last;
            }

            push @entry_lines,
                substr( $file_content, $pos, $next_newline - $pos );
            $pos = $next_newline + 1;
        }

        push @entries, [ $timestamp, \@entry_lines ];
    }

    return @entries if wantarray;
    return \@entries;
}

sub read_timestamped_multiline_recent {

    my $filename    = shift;
    my $max_count   = shift // 50;
    my @all_entries = read_all_timestamped_multiline($filename);

    return undef if not @all_entries;

    ## Return only last max_count entries
    my $start_idx
        = ( @all_entries > $max_count ) ? @all_entries - $max_count : 0;
    return @all_entries[ $start_idx .. $#all_entries ] if wantarray;
    return [ @all_entries[ $start_idx .. $#all_entries ] ];
}

return TRUE ##################################################################

#,,,.,..,,,,,,.,.,..,,,,.,,..,.,,,,,,,,,.,.,,,..,,...,...,...,,,.,,.,,...,,,,,
#SH7ZKSH6YLV5HBS5VTDBFYP4EXRUN6QMLFDHJNMOCBJC2MCLMTAJDJBAPEUM4HCSCE5FJOPLMYEMM
#\\\|HT5FWZN5V45SFZLSJVMEWP4F77OQD22VUUJYFVSL5KBVN5XG5IK \ / AMOS7 \ YOURUM ::
#\[7]K33UX2BBJ4RX7IX2QQMSOMULPZIBDITZ77YLLWEPBCBLLXVPW2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
