#!/usr/bin/perl

use v5.28;
use strict;
use warnings;

# test script for base.parser.list width alignment bug
# reproduces and verifies the ex0:ex1 key pattern fix

my $spacing = 4;

sub mock_align {
    my ( $mode, $string, $field_len ) = @_;
    $string //= '';
    $string =~ s#^ +| +$##g;
    $field_len = length($string) if not defined $field_len or $field_len <= 0;
    return pack( "A$field_len", $string );
}

sub mock_call_filter {
    my ( $filters, $key, $val ) = @_;
    return $val;
}

sub run_parser_list {
    my ( $data_ref, $display_keys ) = @_;
    my %max_len;
    my $table_string = "\n";
    my $table_width  = 0;

    # .: preparation :.
    foreach my $key_name ( @$display_keys ) {
        my $index        = 0;
        my $key_name_str = $key_name;
        my $key_orig_str = $key_name;
        if ( $key_name_str =~ s|^<key>:|| ) {
            $index        = 1;
            $key_orig_str = $key_name_str;
        } else {
            $key_name_str =~ s|^([^:]+):([^:]+)$|$2|;
            $key_orig_str = $1 if defined $1;
        }
        $max_len{$key_name} = length($key_name_str) + $spacing + 3;
        foreach my $key_val ( keys %$data_ref ) {
            my $value_str = $key_val;
            if ( $index == 0 ) {
                $value_str = $data_ref->{$key_val}->{$key_orig_str};
            }
            $value_str //= '';
            my $filtered_val = mock_call_filter( undef, $key_orig_str,
                $value_str );
            $max_len{$key_name} = length($filtered_val) + 4
                if length($filtered_val) > $max_len{$key_name} - 3;
        }
        $table_width += $max_len{$key_name};
    }

    # .: header :.
    foreach my $key_name ( @$display_keys ) {
        my $key_name_str = $key_name;
        $key_name_str =~ s|^<key>:||;
        $key_name_str =~ s|^[^:]+:([^:]+)$|$1|;
        $table_string
            .= pack( "A$max_len{$key_name}", " : " . $key_name_str . " :." );
    }
    $table_string =~ s| +$||;
    my $last_d_key = $$display_keys[ scalar @$display_keys - 1 ];
    $table_width--;
    my $sub_line  .= '-' x $table_width;
    $table_string .= "\n$sub_line\n";

    # .: data :.
    foreach my $key_val ( sort keys %$data_ref ) {
        foreach my $key_name ( @$display_keys ) {
            my $key_name_str = $key_name;
            if ( $key_name_str =~ s|^<key>:|| ) {
                $table_string .= '  '
                    . mock_align( 'left', $key_val,
                    $max_len{$key_name} - 3 )
                    . ' ';
            } else {
                my $len = $max_len{$key_name};
                $key_name_str =~ s|:.+$||;
                my $value = $data_ref->{$key_val}->{$key_name_str} // '';
                $table_string .= mock_align( 'left', $value, $len - 1 ) . ' ';
            }
        }
        $table_string =~ s| +$||;
        $table_string .= "\n";
    }

    return $table_string . "\n", \%max_len;
}

sub assert_not_truncated {
    my ( $name, $output, $data_ref, $display_keys ) = @_;
    my @lines = split m|\n|, $output;

    my @data_lines;
    foreach my $line (@lines) {
        next if $line =~ m|^\s*-+\s*$|;
        next if $line =~ m|:\.|;
        next if $line =~ m|^\s*$|;
        push @data_lines, $line;
    }

    my $last_key = $display_keys->[-1];
    my $last_field = $last_key;
    $last_field =~ s|:.+$||;

    foreach my $data_line (@data_lines) {
        # extract last token from data line
        my $last_token;
        if ( $data_line =~ m|\S+\s+(\S+)$| ) {
            $last_token = $1;
        } elsif ( $data_line =~ m|^(\S+)$| ) {
            $last_token = $1;
        }

        # find which key this row belongs to
        my $row_key;
        foreach my $k ( keys %$data_ref ) {
            my $expected_val = $data_ref->{$k}->{$last_field} // '';
            if ( defined $last_token
                and index( $expected_val, $last_token ) == 0 ) {
                $row_key = $k;
                last;
            }
        }

        if ( defined $row_key ) {
            my $expected_val = $data_ref->{$row_key}->{$last_field} // '';
            if ( defined $last_token
                and length($last_token) < length($expected_val) ) {
                die "[$name] value truncated: expected='$expected_val' "
                    . "got='$last_token' (" . length($expected_val)
                    . " vs " . length($last_token) . ")\n"
                    . "  line: '$data_line'";
            }
        }
    }

    print "  [$name] not truncated\n";
}

sub assert_aligned {
    my ( $name, $output, $max_len, $display_keys ) = @_;
    my @lines = split m|\n|, $output;

    my ( $header_line, $sep_line );
    my @data_lines;
    foreach my $line (@lines) {
        if ( $line =~ m|^\s*-+\s*$| ) {
            $sep_line = $line;
        } elsif ( !defined $header_line && $line =~ m|:\.| ) {
            $header_line = $line;
        } elsif ( length($line) > 0 && $line !~ m|^\s*$| ) {
            push @data_lines, $line;
        }
    }

    die "[$name] no header found"  if not defined $header_line;
    die "[$name] no separator found" if not defined $sep_line;

    my $sep_len = length($sep_line);

    # verify no data row exceeds separator width
    foreach my $data_line (@data_lines) {
        my $data_len = length($data_line);
        if ( $data_len > $sep_len ) {
            die "[$name] data overflow: data=$data_len sep=$sep_len\n"
                . "  data: '$data_line'";
        }
    }

    print "  [$name] aligned\n";
}

print "base.parser.list width alignment tests\n";
print "=" x 40 . "\n";

# [ test 1 ] plain keys
my $data_plain = {
    'key1' => { 'name' => 'alice', 'size' => '10' },
    'key2' => { 'name' => 'bob',   'size' => '200' },
};
my ( $out_plain, $ml_plain )
    = run_parser_list( $data_plain, [ 'name', 'size' ] );
assert_aligned( 'plain keys', $out_plain, $ml_plain, [ 'name', 'size' ] );
assert_not_truncated( 'plain keys', $out_plain, $data_plain,
    [ 'name', 'size' ] );

# [ test 2 ] <key>: prefix
my $data_key_prefix = {
    'sess-1' => { 'user' => 'alice', 'host' => 'box1' },
    'sess-2' => { 'user' => 'bob',   'host' => 'box2' },
};
my ( $out_key_prefix, $ml_key_prefix ) = run_parser_list(
    $data_key_prefix,
    [ '<key>:session', 'user', 'host' ]
);
assert_aligned( '<key>: prefix', $out_key_prefix, $ml_key_prefix,
    [ '<key>:session', 'user', 'host' ] );
assert_not_truncated( '<key>: prefix', $out_key_prefix, $data_key_prefix,
    [ '<key>:session', 'user', 'host' ] );

# [ test 3 ] ex0:ex1 keys with long last value
my $data_ex0ex1 = {
    'row1' => { 'foo' => 'short', 'bar' => '123456789012345678901' },
    'row2' => { 'foo' => 'medium_len', 'bar' => 'x' },
};
my ( $out_ex0ex1, $ml_ex0ex1 )
    = run_parser_list( $data_ex0ex1, [ 'foo:col1', 'bar:col2' ] );
assert_aligned( 'ex0:ex1 keys', $out_ex0ex1, $ml_ex0ex1,
    [ 'foo:col1', 'bar:col2' ] );
assert_not_truncated( 'ex0:ex1 keys', $out_ex0ex1, $data_ex0ex1,
    [ 'foo:col1', 'bar:col2' ] );

# [ test 4 ] mixed patterns
my $data_mixed = {
    'r1' => { 'plain' => 'a', 'field' => 'bb', 'name' => 'ccc' },
    'r2' => { 'plain' => 'dd', 'field' => 'e', 'name' => 'fffff' },
};
my ( $out_mixed, $ml_mixed ) = run_parser_list(
    $data_mixed,
    [ 'plain', 'field:alias', '<key>:id', 'name' ]
);
assert_aligned( 'mixed patterns', $out_mixed, $ml_mixed,
    [ 'plain', 'field:alias', '<key>:id', 'name' ] );
assert_not_truncated( 'mixed patterns', $out_mixed, $data_mixed,
    [ 'plain', 'field:alias', '<key>:id', 'name' ] );

# [ test 5 ] single column ex0:ex1 with long value
my $data_single = {
    'k1' => { 'foo' => '12345678901234567890' },
    'k2' => { 'foo' => 'beta' },
};
my ( $out_single, $ml_single )
    = run_parser_list( $data_single, ['foo:display'] );
assert_aligned( 'single column ex0:ex1', $out_single, $ml_single,
    ['foo:display'] );
assert_not_truncated( 'single column ex0:ex1', $out_single, $data_single,
    ['foo:display'] );

# [ test 6 ] <key> as last column with long keys
my $data_key_last = {
    'very-long-session-id' => { 'user' => 'alice' },
    'another-long-one'     => { 'user' => 'bob' },
};
my ( $out_key_last, $ml_key_last ) = run_parser_list(
    $data_key_last,
    [ 'user', '<key>:session' ]
);
assert_aligned( '<key> last column', $out_key_last, $ml_key_last,
    [ 'user', '<key>:session' ] );
assert_not_truncated( '<key> last column', $out_key_last, $data_key_last,
    [ 'user', '<key>:session' ] );

print "=" x 40 . "\n";
print "all tests passed\n";

#,,,.,,.,,,..,.,,,.,.,.,,,,,.,,,,,,,,,,.,,,..,.,.,...,...,..,,.,,,.,.,.,,,.,,,
#YLTDYAIOZTJRKPEF7KA4YLK4WWWYU5YLXW7OPOZGHKRZ5RSCH3RKOJL2XZHQ7UEUFKQ43CSACJ5C6
#\\\|EFKIOCMHXX4RSO5CC7T35PGTY4WIZIR7FAYJINE3CB6HCECTNPG \ / AMOS7 \ YOURUM ::
#\[7]BYA72LVZGPQRUY4C4Z4QTXC4JSDZEUWZ2OUSBEOV4FRPUFTAC2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
