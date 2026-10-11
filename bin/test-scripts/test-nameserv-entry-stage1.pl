#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv stage-1 record timestamps, tombstones, zone checksum and the    ##
## last-data-timestamp command                                              ##
## [ 2026-10-11, data/md/design/TIMESTAMP- DELTA-SYNC.md stage 1 ] compiles ##
## the real src/nameserv.* modules and drives them with stubs :             ##
## base.ntime.b32 / delta_seconds / b32_is_shape_valid,                     ##
## base.chk-sum.bmw.512.B32, format.yaml.*, file.slurp /                    ##
## file.zenka_dir.write, base.logs and nameserv.event.emit.  a tiny source  ##
## translator expands <[mod]> and <data.key> syntax the way bin/Protocol-7  ##
## does. no zenka started, restarted or reloaded, no network, sandbox zone  ##
## dir only.                                                                ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use Data::Dumper;

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
}

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root_path = $main::root_path;

## tiny base32 [ lowercase, no padding ] -- internal consistency only ##

my @b32_alphabet = split //, 'abcdefghijklmnopqrstuvwxyz234567';

sub encode_b32 {
    my $bytes = shift;
    my $bits  = unpack 'B*', $bytes;
    $bits .= '0' x ( 5 - length($bits) % 5 ) if length($bits) % 5;
    return join '',
        map { $b32_alphabet[ oct "0b$ARG" ] } $bits =~ m|(.....)|g;
}

sub decode_b32 {
    my $str  = shift;
    my %val  = map { $b32_alphabet[$ARG] => $ARG } 0 .. 31;
    my $bits = join '', map { sprintf '%05b', $val{$ARG} // return undef }
        split //, lc $str;
    $bits = substr $bits, 0, length($bits) - length($bits) % 8;
    return pack 'B*', $bits;
}

## ntime shims : same shape the real base.ntime.* modules produce ##
## [ base32 of one compressed integer, 4200 ticks per second ]    ##

sub ntime_val { return time() * 4200 }

sub ntime_b32 { return encode_b32( pack 'w', ntime_val() ) }

sub ntime_b32_at {
    my $epoch = shift;
    return encode_b32( pack 'w', $epoch * 4200 );
}

sub ntime_from_b32 {
    my $ts = shift;
    return undef if $ts !~ m|^[a-z2-7]+$|;
    my $bytes = decode_b32($ts);
    return undef if not defined $bytes;
    my @parts = unpack 'w*', $bytes;
    return @parts == 1 ? $parts[0] : undef;
}

## state ##

our %data;
our %code;
our $call;    ## cmd modules read the command parameter from here ##

$data{'nameserv'}{'zones'}                         = {};
$data{'nameserv'}{'zone_dir'}                      = '';
$data{'nameserv'}{'cfg'}{'default_ttl'}            = 3900;
$data{'nameserv'}{'cfg'}{'challenge_ttl'}          = 60;
$data{'nameserv'}{'cfg'}{'sync'}{'tombstone_keep'} = 1123200;

$code{'base.logs'}           = sub { return 1 };
$code{'base.s_warn'}         = sub { return 1 };
$code{'base.str.os_err'}     = sub { return '' };
$code{'nameserv.event.emit'} = sub { return 1 };

$code{'base.ntime.b32'}                = sub { return ntime_b32() };
$code{'base.ntime.b32_is_shape_valid'} = sub {
    my $ts = shift // '';
    return FALSE if not length $ts;
    return
          ( $ts =~ m|^\d+(?:\.\d+)?$| ) ? TRUE
        : defined ntime_from_b32($ts)   ? TRUE
        :                                 FALSE;
};
$code{'base.ntime.delta_seconds'} = sub {
    my $start = shift // '';
    my $end   = shift;
    my $start_val
        = $start =~ m|^\d+(?:\.\d+)?$|
        ? $start
        : ntime_from_b32($start);
    return undef if not defined $start_val;
    my $end_val = defined $end ? $end : ntime_val();
    $end_val = ntime_from_b32($end_val)
        if $end_val !~ m|^\d+(?:\.\d+)?$|;
    return undef if not defined $end_val;
    return ( $end_val - $start_val ) / 4200;
};

$code{'base.chk-sum.bmw.512.B32'} = sub {
    require Digest::BMW;
    my $input = shift;
    my $bytes = ref $input eq 'SCALAR' ? $input->$* : $input;
    return encode_b32( scalar Digest::BMW::bmw_512($bytes) );
};

$code{'format.yaml.dump_str'} = sub {
    require YAML::XS;
    my $yaml = eval { YAML::XS::Dump( $_[0] ) };
    return $@ ? undef : $yaml;
};
$code{'format.yaml.load_str'} = sub {
    require YAML::XS;
    my $yaml = shift // '';
    my $data = eval { YAML::XS::Load($yaml) };
    return $@ ? ( undef, $EVAL_ERROR ) : ( $data, undef );
};
$code{'file.slurp'} = sub {
    my $path = shift;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return \$content;
};

my $sandbox_dir = tempdir( CLEANUP => 1 );
my $var_dir     = File::Spec->catdir( $sandbox_dir, 'var' );
my $zone_dir    = File::Spec->catdir( $var_dir,     'zones' );
mkdir $var_dir;
mkdir $zone_dir;

$data{'nameserv'}{'zone_dir'} = $zone_dir;

$code{'file.zenka_dir.write'} = sub {
    my $rel     = shift;
    my $content = shift;
    my $path    = File::Spec->catfile( $var_dir, split m|/|, $rel );
    open my $fh, '>', $path or return undef;
    print {$fh} $content->$*;
    close $fh;
    return TRUE;
};

## module loader : translate p7 syntax, compile as anonymous sub ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

for my $mod (
    qw|
    nameserv.entry.identity
    nameserv.zone.tombstone.add
    nameserv.zone.tombstone.clear
    nameserv.zone.tombstone.purge
    nameserv.zone.timestamp
    nameserv.zone.checksum
    nameserv.zone.lookup
    nameserv.zone.save
    nameserv.zones.load
    nameserv.cmd.set-record
    nameserv.cmd.remove-record
    nameserv.cmd.add-txt
    nameserv.cmd.remove-txt
    nameserv.cmd.ensure-zone
    nameserv.cmd.last-data-timestamp
    |
) {
    load_module($mod);
}

## assertion helpers ##

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub cmd {    ## call a nameserv.cmd.* module with an args string ##
    my $name = shift;
    my $args = shift;
    $call = { 'args' => $args };
    return $code{"nameserv.cmd.$name"}->($call);
}

my $zones = $data{'nameserv'}{'zones'};

## --- set-record stamps ts, last-data-timestamp replies --------------- ##

my $res = cmd( 'set-record', 'test.zone A www 10.0.0.1' );
check 'set-record true', $res->{'mode'} eq 'true';
check 'set-record stored ' . 'ts',
    length( $zones->{'test.zone'}{'records'}[0]{'ts'} // '' );
check 'set-record ts is b32 ntime',
    $code{'base.ntime.b32_is_shape_valid'}
    ->( $zones->{'test.zone'}{'records'}[0]{'ts'} );

$res = cmd( 'last-data-timestamp', '' );
my ( $set_reply, $set_ts ) = split m|\s+|, $res->{'data'};
check 'set reply true', $res->{'mode'} eq 'true';
check 'set reply has ts', ( $set_reply eq 'TRUE' and length $set_ts );
check 'set ts matches record ' . 'ts',
    $set_ts eq $zones->{'test.zone'}{'records'}[0]{'ts'};

$res = cmd( 'last-data-timestamp', 'test.zone' );
my ( $zone_reply, $zone_ts, $zone_sum ) = split m|\s+|, $res->{'data'};
check 'zone reply true',     $res->{'mode'} eq 'true';
check 'zone reply ts',       $zone_ts eq $set_ts;
check 'zone reply checksum', length($zone_sum) > 20;

$res = cmd( 'last-data-timestamp', 'no-such.zone' );
check 'unknown zone false', $res->{'mode'} eq 'false';

## --- checksum is order independent ----------------------------------- ##

my $sum_before = $code{'nameserv.zone.checksum'}->('test.zone');
cmd( 'set-record', 'test.zone A mail 10.0.0.2' );
cmd( 'add-txt',    'www.test.zone v=spf1-x' );
push @{ $zones->{'test.zone'}{'records'} },
    {
    name  => 'www.test.zone',
    type  => 'TXT',
    value => 'extra-value',
    ts    => ntime_b32(),
    };
my $zone_href = $zones->{'test.zone'};
$zone_href->{'records'} = [ reverse @{ $zone_href->{'records'} } ];
my $sum_reordered = $code{'nameserv.zone.checksum'}->('test.zone');
check 'checksum order independent',
    (       $sum_reordered ne $sum_before
        and $sum_reordered eq $code{'nameserv.zone.checksum'}->('test.zone')
    );

## --- deletes leave tombstones, re-add clears them -------------------- ##

my $records_before = scalar @{ $zone_href->{'records'} };
$res = cmd( 'remove-txt', 'www.test.zone v=spf1-x' );
check 'remove-txt true', $res->{'mode'} eq 'true';
check 'record removed',
    scalar( @{ $zone_href->{'records'} } ) == $records_before - 1;
my @tombs = @{ $zone_href->{'tombstones'} // [] };
check 'tombstone recorded', scalar @tombs == 1;
check 'tombstone identity',
    (       $tombs[0]{'name'} eq 'www.test.zone'
        and $tombs[0]{'type'} eq 'TXT'
        and $tombs[0]{'value'} eq 'v=spf1-x' );
check 'tombstone has deleted ts', length( $tombs[0]{'deleted'} // '' );

## checksum excludes tombstones : same live records, same checksum ##
my $sum_after_removal = $code{'nameserv.zone.checksum'}->('test.zone');
$zone_href->{'records'} = [ reverse @{ $zone_href->{'records'} } ];
check 'checksum ignores tombstones',
    $code{'nameserv.zone.checksum'}->('test.zone') eq $sum_after_removal;

$res = cmd( 'add-txt', 'www.test.zone v=spf1-x' );
check 're-add true', $res->{'mode'} eq 'true';
check 're-add cleared ' . 'tombstone',
    not scalar @{ $zone_href->{'tombstones'} // [] };
check 're-added record has ts',
    length(
    ( grep { $ARG->{'value'} eq 'v=spf1-x' } @{ $zone_href->{'records'} } )
    [0]{'ts'} // '' );

## remove-record tombstones each removed record ##

$res = cmd( 'remove-record', 'zone=test.zone name=www.test.zone type=TXT' );
check 'remove-record true', $res->{'mode'} eq 'true';
check 'remove-record tombstoned values',
    scalar @{ $zone_href->{'tombstones'} // [] } >= 2;

## set-record replacing a value of another identity tombstones it ##

cmd( 'set-record', 'repl.zone A host 10.0.0.7' );
cmd( 'set-record', 'repl.zone A host 10.0.0.8' );
my $repl_href = $zones->{'repl.zone'};
check 'replace keeps ' . 'one live record',
    scalar @{ $repl_href->{'records'} } == 1;
check 'replaced value tombstoned',
    scalar( grep { $ARG->{'value'} eq '10.0.0.7' }
        @{ $repl_href->{'tombstones'} // [] } ) == 1;
cmd( 'set-record', 'repl.zone A host 10.0.0.8' );
check 'same value re-set : no new tombstone',
    scalar @{ $repl_href->{'tombstones'} // [] } == 1;

## one tombstone per identity ##

cmd( 'set-record', 'repl.zone A host 10.0.0.7' );
cmd( 'set-record', 'repl.zone A host 10.0.0.8' );
check 'repeated delete : one tombstone per identity',
    scalar( grep { $ARG->{'value'} eq '10.0.0.7' }
        @{ $repl_href->{'tombstones'} // [] } ) == 1;

## --- save writes zone + tombstones, load reads both ------------------ ##

$code{'nameserv.zone.save'}->('test.zone');
check 'zone file ' . 'written',
    -f File::Spec->catfile( $zone_dir, 'test.zone.yaml' );
check 'tombstones written',
    -f File::Spec->catfile( $zone_dir, 'test.zone.tombstones.yaml' );
my $saved_count = scalar @{ $zone_href->{'records'} };
my $saved_tombs = scalar @{ $zone_href->{'tombstones'} // [] };

## hand-written zone without ts stays loadable [ oldest ] ##

$code{'file.zenka_dir.write'}->(
    'zones/hand.zone.yaml',
    \YAML::XS::Dump(
        {   serial  => 424242,
            ttl     => 3900,
            records => [
                { name => 'www.hand.zone', type => 'A', value => '10.1.1.1' }
            ],
        }
    )
);

$code{'nameserv.zones.load'}->();
check 'reload keeps live records',
    scalar @{ $zones->{'test.zone'}{'records'} } == $saved_count;
check 'reload restores tombstones',
    scalar @{ $zones->{'test.zone'}{'tombstones'} // [] } == $saved_tombs;
check 'hand-written zone loaded', exists $zones->{'hand.zone'};
check 'tombstone ' . 'file not a zone',
    not exists $zones->{'test.zone.tombstones'};

$res = cmd( 'last-data-timestamp', 'hand.zone' );
check 'zone without ts : false', $res->{'mode'} eq 'false';
$res = cmd( 'last-data-timestamp', '' );
my $set_after_reload = ( split m|\s+|, $res->{'data'} )[1];
check 'set ts across zones',
    (       $set_after_reload eq $code{'nameserv.zone.timestamp'}->()
        and $set_after_reload eq
        $code{'nameserv.zone.timestamp'}->('test.zone') );

## --- expired tombstones dropped on save ------------------------------ ##

push @{ $zones->{'test.zone'}{'tombstones'} },
    {
    name    => 'old.test.zone',
    type    => 'A',
    value   => '10.9.9.9',
    deleted => ntime_b32_at( time() - 20 * 86400 ),
    };
my $total_tombs = scalar @{ $zones->{'test.zone'}{'tombstones'} };
$code{'nameserv.zone.save'}->('test.zone');
check 'expired tombstone dropped',
    scalar @{ $zones->{'test.zone'}{'tombstones'} } == $total_tombs - 1;

## --- ensure-zone stamps ts ------------------------------------------- ##

$res = cmd( 'ensure-zone', 'acme.test.zone ns1.test.zone.' );
check 'ensure-zone true', $res->{'mode'} eq 'true';
check 'ensure-zone records ts',
    scalar( grep { length( $ARG->{'ts'} // '' ) }
        @{ $zones->{'acme.test.zone'}{'records'} } ) == 2;

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,.,,,,.,,,,,.,,,..,,,..,,..,..,,,..,.,,,,,,,..,,...,...,.,.,...,,..,,,,,...,
#6AFDOZCDUKW6DTPGC53RB652L7NUVDJ4BAWOIJAN2YD5QQZZLS6ETMWZNEOYOSTCX3U6UPSUFCNEA
#\\\|NIP2355OH5BALBON5DKELRJJ3VLNQHEENZO2QDJ657NPTOMBMX2 \ / AMOS7 \ YOURUM ::
#\[7]EDDKS2H5DMND7GGP4E2LQ7BS22IAORF2FRPUQUO5EZG6SGVJ7AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
