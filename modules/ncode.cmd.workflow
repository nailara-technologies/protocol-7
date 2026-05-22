## [:< ##

# name  = ncode.cmd.workflow
# descr = ncode workflow: detect, fix, verify, suggest

my $params = shift // {};

my $name  = $params->{'name'}  // '';
my $files = $params->{'files'} // [];

return { 'mode' => qw| false |, 'data' => 'workflow name required' }
    unless length $name;

## normalize file list ##
my @file_list;
if ( ref $files eq qw| ARRAY | ) {
    @file_list = @$files;
} elsif ( length $files ) {
    @file_list = ($files);
}

<ncode.workflows> //= {};
my $workflows = <ncode.workflows>;
my $frame     = $workflows->{$name};

## attempt to load from pattern directory if not in memory ##
if ( not defined $frame ) {
    my $pattern_dir = <ncode.cfg.pattern_dir> // 'data/yaml/ncode-patterns';
    if ( $pattern_dir !~ m|^/| and defined <system.root_path> ) {
        $pattern_dir = <system.root_path> . '/' . $pattern_dir;
    }

    my @yaml_files = glob "$pattern_dir/*.yaml";
    foreach my $yfile (@yaml_files) {
        next unless -f $yfile;

        my $yaml_fn = $code{'format.yaml.load_file'};
        my $data;
        if ( defined $yaml_fn ) {
            $data = $yaml_fn->($yfile);
        } else {
            eval {
                <[base.perlmod.load]>->('YAML::XS');
                $data = YAML::XS::LoadFile($yfile);
            };
        }
        next unless ref $data eq qw| HASH |;

        my $wfs = $data->{'workflows'} // [];
        next unless ref $wfs eq qw| ARRAY |;

        foreach my $wf (@$wfs) {
            next unless ref $wf eq qw| HASH |;
            my $wf_name = $wf->{'name'} // next;
            $workflows->{$wf_name} = $wf;
        }
    }
    $frame = $workflows->{$name};
}

return { 'mode' => qw| false |, 'data' => "workflow '$name' not found" }
    unless defined $frame and ref $frame eq qw| HASH |;

## run detect if present ##
my $triggered = 1;
if (    defined $frame->{'detect'}
    and ref $frame->{'detect'} eq qw| HASH |
    and length( $frame->{'detect'}{'trigger'} // '' ) ) {
    $triggered = 0;
    foreach my $file (@file_list) {
        next unless -f $file;
        $triggered = 1;
        last;
    }
}

return { 'mode' => 'size', 'data' => "workflow '$name' not triggered" }
    unless $triggered;

## run sequence ##
my $sequence  = $frame->{'sequence'} // [];
my $all_pass  = 1;
my $steps_run = 0;

foreach my $step (@$sequence) {
    next unless ref $step eq qw| HASH |;

    my $pattern_name = $step->{'pattern'} // '';
    my $step_name    = $step->{'step'}    // '';

    if ( length $pattern_name ) {
        <ncode.patterns> //= {};
        my $def = <ncode.patterns>->{$pattern_name};
        if ( not defined $def or ref $def ne qw| HASH | ) {
            <[base.logs]>->(
                1, ':. ncode.cmd.workflow: pattern %s not loaded :.',
                $pattern_name
            );
            $all_pass = 0;
            last;
        }

        my $steps = $def->{'steps'} // [];
        foreach my $file (@file_list) {
            next unless -f $file;

            open my $fh, '<', $file or next;
            local $/ = undef;
            my $content = <$fh>;
            close $fh;
            my $original = $content;

            foreach my $pstep (@$steps) {
                my $tool = $pstep->{'tool'} // '';
                if ( $tool eq qw| ncode | or $tool eq qw| perl | ) {
                    my $search = $pstep->{'search'} // $pstep->{'pattern'}
                        // '';
                    my $replace = $pstep->{'replace'} // '';
                    next unless length $search;

                    my $compiled = eval {qr/$search/};
                    next if $@;

                    my @lines = split m|\n|, $content;
                    for my $i ( 0 .. $#lines ) {
                        $lines[$i] =~ s|$compiled|$replace|;
                    }
                    $content = join "\n", @lines;
                    $content .= "\n" if $original =~ m|\n$|;
                }
            }

            if ( $content ne $original ) {
                open my $wfh, '>', $file or next;
                print {$wfh} $content;
                close $wfh;
            }
        }
    } elsif ( length $step_name ) {
        <[base.logs]>->(
            2, ':. ncode.cmd.workflow: running step %s :.', $step_name
        );
    }

    $steps_run++;

    ## step-level verify ##
    my $verify = $step->{'verify'} // '';
    if ( length $verify ) {
        <[base.logs]>->( 2, ':. ncode.cmd.workflow: verify %s :.', $verify );
    }
}

my $suggest_next = $frame->{'suggest_next'} // '';
my $summary      = "workflow '$name': $steps_run steps run";
$summary .= ", all pass"                    if $all_pass;
$summary .= ", suggest_next: $suggest_next" if length $suggest_next;

return { 'mode' => 'size', 'data' => $summary };

#,,,,,..,,,.,,,,,,...,..,,,,.,..,,,,.,.,.,,,,,.,.,...,...,..,,..,,,,.,.,.,.,,,
#H3SOHDIUAHFUMIOBRSWT26X6QJB3GXWTYWDXNBWX3MK4J244YMT3TMZAYLAMI7EH3YLEQVAFQTZTO
#\\\|KMOP7GPXDTNYDKFFSB3LOYVUJ23WEYUB72VFT6ZHGJGSNVW6S5L \ / AMOS7 \ YOURUM ::
#\[7]BBWPZ4J3UT5W6SGVBEFX4ZQUI7ZUM5ZVQN6GBTCXWSWO3VKSVSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
