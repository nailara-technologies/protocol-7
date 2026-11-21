package AMOS7::Perms;
our $VERSION = qw| AMOS7::Perms-VERSION.H5XLAGQ |;

use v5.32;
use strict;
use warnings;
use English;

use Exporter;
use base qw| Exporter |;

our @EXPORT_OK = qw| parse_rules |;

## rule text -> ordered path, flags, mode, user, group and link target data ##
sub parse_rules {
    my $file_str = shift // '';

    ## a comment starts a line or follows whitespace : '#' inside a path ##
    ## [ editor lock links '.#name' ] stays part of it                   ##
    $file_str =~ s{(?:^|[ \t]+)#[^\n]*}{}mg;
    $file_str =~ s|^\n+||mg;
    $file_str =~ s|\n$||;

    my @rules;
    foreach my $perm_line ( split "\n", $file_str ) {
        my ( $rules_str, $path_str, $target_str )
            = split( m| *-?-> *|, $perm_line );
        my @actions = split( m|\s+|, $rules_str );
        push @actions, sprintf( 'link_target:%s', $target_str )
            if defined $target_str;

        my $rule = {
            'path'        => $path_str,
            'flags'       => [],
            'mode'        => undef,
            'user'        => undef,
            'group'       => undef,
            'link_target' => undef,
            '_actions'    => \@actions,
            '_operations' => [],
        };
        my ( $on_files, $on_links, $on_dirs ) = ( 0, 0, 0 );
        foreach my $param_str (@actions) {
            if ( $param_str =~ m|^[RFLDC]+$| ) {
                push $rule->{'flags'}->@*,       $param_str;
                push $rule->{'_operations'}->@*, 'flags';
                $on_files = 1 if $param_str =~ m|F|;
                $on_links = 1 if $param_str =~ m|L|;
                $on_dirs  = 1 if $param_str =~ m|D|;
            } elsif ( $param_str =~ m|^link_target:\s*(.+)$|
                and $on_files + $on_links + $on_dirs == 1
                and $on_links ) {
                $rule->{'link_target'} = $LAST_PAREN_MATCH;
                push $rule->{'_operations'}->@*, 'link';
            } elsif ( $param_str =~ m|^([ug]):(\w[-_\w\d]*)$| ) {
                $rule->{ $1 eq qw| u | ? 'user' : 'group' } = $2;
                push $rule->{'_operations'}->@*,
                    $1 eq qw| u | ? 'user' : 'group';
            } elsif ( $param_str =~ m|^([0-9]+)$| ) {
                $rule->{'mode'}
                    = oct( sprintf qw| %04d |, $LAST_PAREN_MATCH );
                push $rule->{'_operations'}->@*, 'mode';
            }
        }
        push @rules, $rule;
    }
    return \@rules;
}

1;    ##  AMOS7::Perms  ##

#,,,,,,.,,.,.,,.,,,,,,,,,,,..,,,.,,.,,...,.,,,..,,...,...,,,.,.,.,.,,,,.,,..,,
#ECLOZRMXSM2DE7UOIJZCPOVVHKANKSEV6K322LZRZHNRQC6FXMTZBBO5EF62GJZMAXD7XE3H3RBBO
#\\\|2FH7BWTCHUDWZH7PTOJUKYSJEUZWBU62CIR4HOJQM4SIV7AZSGB \ / AMOS7 \ YOURUM ::
#\[7]CIRFDAD5RKDL4ZB7O747YFWGKQC23NMZGC5FLNWPAH64AA4TPGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
