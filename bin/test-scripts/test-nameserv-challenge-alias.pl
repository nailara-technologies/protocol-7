#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## nameserv ensure-challenge-alias : parent held \ not held \ hand cname \
## foreign cname \ idempotence \ :remove: -- stub zones, no network, no disk.

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;
our $call;

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $cref
        = eval "$runtime_pragmas sub {\n"
        . q{my $call = ref $ARG[0] eq 'HASH' ? $ARG[0] : { 'args' => $ARG[0] };}
        . "\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG) for qw| nameserv.cmd.ensure-challenge-alias
    nameserv.cmd.ensure-zone nameserv.zone.lookup
    nameserv.challenge_alias.is_managed |;

use File::Temp qw| tempdir |;
my $src_dir = tempdir( CLEANUP => 1 );
open( my $sfh, '>', "$src_dir/example.net.zone" ) or die $ERRNO;
print {$sfh} <<'ZONE';
\$ORIGIN example.net.
\$TTL 3000
_acme-challenge.hand IN CNAME _acme-challenge.acme.hand.example.net.
ZONE
close $sfh;

my @logs;
$code{'base.logs'}          = sub { push @logs, $_[1]; return TRUE };
$code{'base.ntime.b32'}     = sub { return 'TS' };
$code{'nameserv.sync.sign'} = sub {
    $_[1]{'writer'} = 'KEY';
    return TRUE;
};
my @tombs;
$code{'nameserv.zone.tombstone.add'} = sub {
    push @tombs, "$_[0] $_[1]{'name'} $_[1]{'type'}";
    return TRUE;
};
$code{$ARG} = sub { return TRUE }
    for qw| nameserv.zone.tombstone.clear nameserv.event.emit |;
my @saved;
$code{'nameserv.zone.save'} = sub { push @saved, $_[0]; return TRUE };
my @removed_zones;
$code{'nameserv.cmd.remove-zone'} = sub {
    my $zone = $_[0]{'args'};
    push @removed_zones, $zone;
    delete $data{'nameserv'}{'zones'}{$zone};
    return { mode => 'true', data => "zone $zone removed" };
};

sub reset_zones {
    $data{'nameserv'} = {
        'cfg' => {
            'default_ttl'     => 3600,
            'challenge_ttl'   => 60,
            'zone_source_dir' => $src_dir
        },
        'zones' => {
            ## held parent : plain records + its own ns ##
            'example.net' => {
                serial  => 1,
                records => [
                    {   name  => 'example.net',
                        type  => 'NS',
                        value => 'ns1.example.net.'
                    },
                    {   name  => 'www.example.net',
                        type  => 'A',
                        value => '203.0.113.7'
                    },
                    ## hand line : canonical cname, also a line in the zone ##
                    ## source                                               ##
                    {   name  => '_acme-challenge.hand.example.net',
                        type  => 'CNAME',
                        value => '_acme-challenge.acme.hand.example.net.',
                        ttl   => 3000
                    },
                    ## foreign cname ##
                    {   name  => '_acme-challenge.other.example.net',
                        type  => 'CNAME',
                        value => '_acme-challenge.elsewhere.example.org.'
                    },
                    ## a txt left by an earlier direct provider ##
                    {   name  => '_acme-challenge.old.example.net',
                        type  => 'TXT',
                        value => 'leftover'
                    },
                ],
            },
            ## acme.* zone holding the parent name : never a parent ##
            'acme.zz.example.org' => { serial => 1, records => [] },
        },
    };
    @saved = @tombs = @removed_zones = ();
    return;
}

sub recs {
    my ( $zone, $name, $type ) = @ARG;
    return
        grep { $ARG->{'name'} eq $name and $ARG->{'type'} eq $type }
        @{ $data{'nameserv'}{'zones'}{$zone}{'records'} };
}

sub run_cmd {
    my ($args) = @ARG;
    return $code{ 'nameserv.cmd.ensu' . 're-challenge-alias' }
        ->( { 'args' => $args } );
}

my $parent = 'example.net';

######################################################################
say ': parent not held';
{
    reset_zones();
    my $r = run_cmd('host1.example.org');
    ok( $r->{'mode'} eq qw| false | && $r->{'data'} =~ m|^not ours|,
        'not ours, mode false' );
    ok( !exists $data{'nameserv'}{'zones'}{'acme.host1.example.org'},
        'no zone created' );
    ok( !@saved, 'nothing saved' );
    $r = run_cmd('zz.example.org');
    ok( $r->{'data'} =~ m|^not ours|, 'an acme.* zone is never a parent' );
    $r = run_cmd(':remove:');
    ok( $r->{'mode'} eq qw| false |, 'usage on a missing domain' );
}

######################################################################
say ': parent held, fresh domain';
{
    reset_zones();
    my $r = run_cmd('host1.example.net ns1.example.org');
    ok( $r->{'mode'} eq qw| true |, "added [ $r->{'data'} ]" );
    my ($c) = recs( $parent, '_acme-challenge.host1.example.net', 'CNAME' );
    ok( $c, 'cname written into the parent zone' );
    ok( $c->{'value'} eq '_acme-challenge.acme.host1.example.net.',
        'value points into acme.<domain>' );
    ok( $c->{'ttl'} == 3000,     'ttl 3000' );
    ok( !exists $c->{'managed'}, 'no stored mark' );
    ok( $code{'nameserv.challenge_alias.is_managed'}->( $parent, $c ),
        'derived : managed' );
    ok( ( $c->{'writer'} // '' ) eq 'KEY', 'signed' );
    my $z = $data{'nameserv'}{'zones'}{'acme.host1.example.net'};
    ok( $z, 'alias zone created' );
    ok( scalar(
            grep {
                        $ARG->{'type'} eq 'NS'
                    and $ARG->{'value'} eq 'ns1.example.org.'
            } $z->{'records'}->@*
        ),
        'ns from the args'
    );
    ok( ( grep { $ARG eq $parent } @saved ), 'parent saved' );

    ## idempotent ##
    @saved = ();
    $r     = run_cmd('host1.example.net ns1.example.org');
    ok( $r->{'mode'} eq qw| true | && $r->{'data'} =~ m|cname present|,
        'second call : present' );
    ok( scalar(
            () = recs( $parent, '_acme-challenge.host1.example.net', 'CNAME' )
        ) == 1,
        'still one cname'
    );
    ok( !( grep { $ARG eq $parent } @saved ), 'parent not saved again' );
}

######################################################################
say ': ns taken from the parent zone when none given';
{
    reset_zones();
    my $r = run_cmd('fresh.example.net');
    ok( $r->{'mode'} eq qw| true |, 'added' );
    my $z = $data{'nameserv'}{'zones'}{'acme.fresh.example.net'};
    ok( scalar(
            grep {
                        $ARG->{'type'} eq 'NS'
                    and $ARG->{'value'} eq 'ns1.example.net.'
            } $z->{'records'}->@*
        ),
        'parent ns used'
    );
}

######################################################################
say ': hand-written cname present';
{
    reset_zones();
    my $r = run_cmd('hand.example.net ns1.example.org');
    ok( $r->{'mode'} eq qw| true | && $r->{'data'} =~ m|hand-written|,
        "no change [ $r->{'data'} ]" );
    my @c = recs( $parent, '_acme-challenge.han' . 'd.example.net', 'CNAME' );
    ok( @c == 1
            && !$code{ 'nameserv.challeng' . 'e_alias.is_managed' }
            ->( $parent, $c[0] ),
        'record untouched, derived : hand'
    );

    $r = run_cmd('hand.example.net :remove:');
    ok( $r->{'mode'} eq qw| true | && $r->{'data'} =~ m|hand-written|,
        'remove : hand record stays' );
    ok( scalar(
            () = recs( $parent, '_acme-challenge.hand.example.net', 'CNAME' )
        ) == 1,
        'cname still there'
    );
    ok( !@tombs && !@removed_zones, 'no tombstone, no zone removed' );
}

######################################################################
say ': foreign cname \ other record type';
{
    reset_zones();
    my $r = run_cmd('other.example.net ns1.example.org');
    ok( $r->{'mode'} eq qw| false | && $r->{'data'} =~ m|^refused|,
        "foreign cname refused [ $r->{'data'} ]" );
    ok( ( recs( $parent, '_acme-challenge.other.example.net', 'CNAME' ) )
            [0]{'value'} eq '_acme-challenge.elsewhere.example.org.',
        'foreign cname untouched'
    );
    ok( !exists $data{'nameserv'}{'zones'}{'acme.other.example.net'},
        'no alias zone made' );
    $r = run_cmd('old.example.net ns1.example.org');
    ok( $r->{'data'} =~ m|^refused|, 'txt at the name : refused' );
    $r = run_cmd('other.example.net :remove:');
    ok( $r->{'mode'} eq qw| true | && !@tombs,
        'remove leaves a foreign cname'
    );
}

######################################################################
say ': :remove:';
{
    reset_zones();
    run_cmd('host1.example.net ns1.example.org');
    ## a txt in the alias zone does not stop the removal ##
    push $data{'nameserv'}{'zones'}{'acme.host1.example.net'}
        {'records'}->@*,
        {
        name  => '_acme-challenge.acme.host1.example.net',
        type  => 'TXT',
        value => 'tok'
        };
    @tombs = ();
    my $r = run_cmd('host1.example.net :remove:');
    ok( $r->{'mode'} eq qw| true |, "removed [ $r->{'data'} ]" );
    ok( !( recs( $parent, '_acme-challenge.host1.example.net', 'CNAME' ) ),
        'cname gone' );
    ok( ( grep {m|_acme-challenge\.host1\.example\.net CNAME|} @tombs ),
        'tombstone written' );
    ok( "@removed_zones" eq 'acme.host1.example.net', 'alias zone removed' );
    ok(
        (   grep { $ARG->{'name'} eq 'www.example.net' }
                $data{'nameserv'}{'zones'}{$parent}{'records'}->@*
        ),
        'other parent records untouched'
    );
    $r = run_cmd('host1.example.net :remove:');
    ok( $r->{'mode'} eq qw| true | && $r->{'data'} =~ m|no alias cname|,
        'second remove : nothing to do' );

    ## alias zone with a hand-written record stays ##
    reset_zones();
    run_cmd('host1.example.net ns1.example.org');
    push $data{'nameserv'}{'zones'}{'acme.host1.example.net'}
        {'records'}->@*,
        {
        name  => 'x.acme.host1.example.net',
        type  => 'A',
        value => '203.0.113.9'
        };
    $r = run_cmd('host1.example.net :remove:');
    ok( !@removed_zones && $r->{'data'} =~ m|kept|,
        'alias zone with a hand record kept'
    );
}

######################################################################
say ': is_managed rule';
{
    reset_zones();
    my $is  = $code{'nameserv.challenge_alias.is_managed'};
    my $rec = sub {
        return { name => $_[0], type => $_[1], value => $_[2] };
    };
    my $canon = '_acme-challenge.acme.new.example.net.';
    ok( $is->(
            $parent,
            $rec->( '_acme-challenge.new' . '.example.net', 'CNAME', $canon )
        ),
        'canonical cname, not in source : managed'
    );
    ok( $is->(
            $parent,
            $rec->(
                '_acme-challenge.new' . '.example.net.',
                'CNAME', uc $canon
            )
        ),
        'case and trailing dot do not matter'
    );
    ok( !$is->(
            $parent,
            $rec->(
                '_acme-challenge.hand.example.net', 'CNAME',
                '_acme-challenge.acme.hand.example.net.'
            )
        ),
        'canonical cname, line in source : hand'
    );
    ok( !$is->(
            $parent,
            $rec->(
                '_acme-challenge.new.example.net', 'CNAME',
                '_acme-challenge.elsewhere.example.org.'
            )
        ),
        'other target : hand'
    );
    ok( !$is->(
            $parent,
            $rec->(
                '_acme-challenge.new.example.net', 'CNAME',
                '_acme-challenge.acme.other.example.net.'
            )
        ),
        'alias of another domain : hand'
    );
    ok( !$is->( $parent, $rec->( 'www.example.net', 'CNAME', $canon ) ),
        'not an _acme-challenge name : hand' );
    ok( !$is->(
            $parent,
            $rec->( '_acme-challenge.new' . '.example.net', 'TXT', $canon )
        ),
        'not a cname : hand'
    );
    ok( !$is->(
            'other.example',
            $rec->(
                '_acme-challenge.q.other.example', 'CNAME',
                '_acme-challenge.acme.q.other.example.'
            )
        ),
        'no source file for the zone : hand [ a secondary never removes ]'
    );
    ## unreadable source [ a directory in the file's place ] : never ours ##
    mkdir "$src_dir/broken.zone" or die $ERRNO;
    ok( !$is->(
            'broken',
            $rec->(
                '_acme-challenge.q.broken', 'CNAME',
                '_acme-challenge.acme.q.broken.'
            )
        ),
        'unreadable source : hand'
    );
    ## relative \ absolute \ continuation owners ##
    open( my $o, '>', "$src_dir/rel.zone" ) or die $ERRNO;
    print {$o} "\$ORIGIN rel.\n_acme-challenge.a IN CNAME "
        . "x.\n_acme-challenge.b.rel. IN CNAME "
        . "x.\n_acme-challenge.c\n    IN TXT t\n";
    close $o;
    my $canon_of = sub {"_acme-challenge.acme.$_[0].rel."};
    ok( !$is->(
            'rel',
            $rec->( "_acme-challenge.$ARG.rel", 'CNAME', $canon_of->($ARG) )
        ),
        "owner $ARG in source : hand"
    ) for qw| a b c |;
    ok( $is->(
            'rel',
            $rec->( '_acme-challenge.d.rel', 'CNAME', $canon_of->('d') )
        ),
        'owner not in source : managed'
    );
}

say '';
say "tests : $test_count, failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,.,,..,,..,,,..,,,.,,..,,,.,,.,,,..,,,.,..,,..,,...,..,,,.,,,,,,,.,,,,,,,,.,
#CWYSCNJUWGWGE32A5RGFQQ7MVJI7W34HQZ32FB3GWKM4CWK7MCWXPMVXHCSCM55EDREHK3FRO7ZAA
#\\\|K47YRO5UUTNZ4HUWX3PDS4AGG53ZBSHASIFYOYZWXYXC2YXKZZS \ / AMOS7 \ YOURUM ::
#\[7]KW33J25LIC7JUFPIL37IHNN3XK6CKFMYYTBWALARB62WLWLYPWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
