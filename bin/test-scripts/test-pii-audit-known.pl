#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;
use File::Temp qw| tempdir |;
use File::Spec;
use FindBin qw| $RealBin |;

##  bin/dev/pii-audit : known findings [ -K writes, -k reads ] on a temp   ##
##  repository with a made-up pattern -- known history stays quiet, a new  ##
##  occurrence of the same pattern is still reported                       ##

my $audit = File::Spec->catfile( $RealBin, qw| .. dev pii-audit | );
my $tmp   = tempdir( CLEANUP => 1 );
my $repo  = File::Spec->catdir( $tmp, 'repo' );
my $pats  = File::Spec->catfile( $tmp, 'patterns' );
my $known = File::Spec->catfile( $tmp, 'known' );

my ( $pass, $fail ) = ( 0, 0 );

sub check {
    my ( $name, $ok ) = @ARG;
    $ok ? $pass++ : $fail++;
    say( ( $ok ? ': ok     : ' : ': FAILED : ' ) . $name );
}

sub git { system( 'git', '-C', $repo, @ARG ) == 0 or die "git @ARG\n" }

sub audit {
    local $ENV{'P7_ROOT'} = $repo;
    my $pid = open( my $fh, '-|' ) // die "fork : $OS_ERROR\n";
    if ( not $pid ) {
        open( STDERR, '>&', \*STDOUT );
        exec( $EXECUTABLE_NAME, $audit, '-p', $pats, '-k', $known, @ARG );
        exit 127;
    }
    my $out = do { local $INPUT_RECORD_SEPARATOR; <$fh> } // '';
    close $fh;
    $out =~ s{\e\[[0-9;]*m}{}g;
    return ( $CHILD_ERROR >> 8, $out );
}

sub write_file {
    my ( $file, $text, $mode ) = @ARG;
    open( my $fh, '>', $file ) or die "$file : $OS_ERROR\n";
    print {$fh} $text;
    close $fh;
    chmod $mode, $file if defined $mode;
}

mkdir $repo or die "$repo : $OS_ERROR\n";
git(qw| init -q |);
git(qw| config user.email t@t |);
git(qw| config user.name t |);
write_file( $pats, "# testcat\nzebra-marker-[0-9]+\n", 0600 );

my $f = File::Spec->catfile( $repo, 'f.txt' );
write_file( $f, "a zebra-marker-1 here\n" );
git(qw| add f.txt |);
git(qw| commit -q -m one |);

my ( $exit, $out ) = audit();
check 'history hit reported before a baseline', $exit == 1;
check 'the output never shows the matched text', $out !~ m{zebra-marker};

( $exit, $out ) = audit('-K');
check '-K exits 0', $exit == 0;
check '-K writes the known file', -s $known;
check 'known file is private [ 0600 ]', ( ( stat $known )[2] & 07777 ) == 0600;
my $known_text = do { local ( @ARGV, $RS ) = $known; <> };
check 'known file holds no matched text', $known_text !~ m{zebra};
check 'known file lines are commit-id + category',
    $known_text =~ m{\A[0-9a-f]{7,} testcat\n\z};

( $exit, $out ) = audit();
check 'known history is quiet [ exit 0 ]', $exit == 0;
check 'the known count is shown', $out =~ m{1 known};

write_file( $f, "a zebra-marker-1 here\nnew zebra-marker-2\n" );
git(qw| commit -q -a -m two |);
( $exit, $out ) = audit();
check 'a NEW occurrence of a known pattern is reported', $exit == 1;
check 'only the new commit is listed',
    ( () = $out =~ m{^:\s+[0-9a-f]{7,} \.:}mg ) == 1;

( $exit, $out ) = audit( '-k', File::Spec->catfile( $tmp, 'missing' ) );
check 'a missing known file means no baseline [ all reported ]',
    $exit == 1;

say ":\n: $pass checks passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,,,,,,.,,,..,,..,.,.,.,.,.,,,,,.,,.,,.,.,..,,...,...,.,,,.,,,.,,,,.,,,,,,
#ZKL5SJ27DN2PNY42FIMLMF4GFNUOXGL6KUGK76S246GPLJ4HN5DEKVSPE437UHJ2NSNEWXOVEAX3A
#\\\|NSUFWI74GHFSM2VS2MI6YGN7EATKWKE4EQMBMDIDOXHYMT6MQA5 \ / AMOS7 \ YOURUM ::
#\[7]WWLPJOIJP4QXSQ2EYCCOPZKHNTG4V63DVG6T7OGFDKVFLMU3ZADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
