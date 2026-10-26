#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;

## scan vault note bodies [ every version ] for control characters and report
## each as offset, hex, caret notation and line/column -- answers "which
## invisible character sits in my scratchpad". usage:
##
##   perl bin/dev/scan-vault-control-chars.pl [vault-dir]
##
## the passphrase is asked hidden ; nothing is printed or logged raw

use FindBin;

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw| vault_open vault_unlock vault_lock entries_latest
    entry_versions |

    ;

my $dir = $ARGV[0] // $ENV{'P7_VAULT_DIR'}
    // sprintf( qw| %s/.n/vault |, $ENV{'HOME'} // ( getpwuid($EUID) )[7] );

die "no vault at $dir\n" if not AMOS7::Vault::vault_exists($dir);

print 'vault passphrase : ';
system qw| stty -echo | if -t STDIN;
my $secret = <STDIN>;
system qw| stty echo | if -t STDIN;
print "\n";
die "aborted\n" if not defined $secret;
chomp $secret;

my ( $v, $open_err ) = AMOS7::Vault::vault_open($dir);
die "$open_err\n" if not defined $v;
AMOS7::Vault::vault_unlock( $v, $secret ) or die "unlock failed\n";
AMOS7::Vault::secret_wipe( \$secret );

my $seen = 0;

sub scan_body {
    my ( $title, $id, $ver, $body ) = @ARG;
    return if not defined $body;
    my $pos  = 0;
    my $line = 1;
    my $lcol = 1;
    for my $ch ( split m||, $body ) {
        my $ord = ord $ch;
        if ( $ch eq "\n" ) { $line++; $lcol = 1; $pos++; next }
        my $bad
            = $ord < 32 || $ord == 127 || ( $ord >= 0x80 && $ord <= 0x9f );
        if ($bad) {
            my $note
                = $ord == 9    ? 'TAB'
                : $ord == 11   ? 'VT  [ cursor down ]'
                : $ord == 12   ? 'FF  [ cursor down ]'
                : $ord == 13   ? 'CR  [ cursor to col 1 ]'
                : $ord == 27   ? 'ESC [ starts an escape sequence ]'
                : $ord == 0x85 ? 'NEL [ newline in utf-8 terminals ]'
                : $ord == 127  ? 'DEL'
                :                'control';
            say sprintf "%-12s id=%.8s.. v%-3s byte %3d 0x%02X "
                . " ^%s  at char %d (line %d, col %d)  %s",
                "'$title'", $id, $ver, $ord, $ord,
                ( $ord == 127 ? '?' : chr( $ord + 64 ) ),
                $pos, $line, $lcol, $note;
            $seen++;
        }
        $pos++;
        $lcol++;
    }
    return;
}

my ( $list, $errors ) = AMOS7::Vault::entries_latest($v);
say STDERR "  << $ARG >>" foreach @{$errors};

my $all_versions = AMOS7::Vault::entry_versions($v);

foreach my $entry ( @{$list} ) {
    my $id    = $entry->{'id'};
    my $title = $entry->{'record'}{'title'} // '';
    my $type  = $entry->{'record'}{'type'}  // '';
    next if $type ne qw| note |;
    foreach my $ver ( @{ $all_versions->{$id} // [] } ) {
        my ( $record, $err ) = AMOS7::Vault::entry_load( $v, $id, $ver );
        say STDERR "  << $err >>" and next if not defined $record;
        scan_body( $title, $id, $ver, $record->{'body'} );
    }
}

AMOS7::Vault::vault_lock($v);
say $seen
    ? "$seen control character(s) found"
    : 'no control characters in any note version';
exit(0);

#,,,,,.,.,,.,,...,,,,,...,,,,,,.,,.,.,.,,,.,,,..,,...,...,,.,,.,,,.,,,,,,,.,,,
#AWLA4VHECA4WGQZSXH656YYWOPOZEH6PIIG73NLR6MSBK3LDAOGPTOGT7K6IKPGU3ZZNXJFASYCZA
#\\\|FMNOYTWZHXHERXQZNOC6H2DGN7OH2CEA72YJOVJZOPU6YRGIFQP \ / AMOS7 \ YOURUM ::
#\[7]P5UXQVNIZPYKUQRRHCOZMAAJGRRRRDPSLIFUPVI6U3ODBMAQPGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
