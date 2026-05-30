## task: filesystem directory-based checksum store for jobsite dedup

### motivation

the current `jobsite.checksum.index` module stores all checksums in a single
YAML file (`/var/protocol-7/jobsite/checksum-index.yaml`). this has two
problems:

1. the file is only written on explicit `persist` calls — `add` actions
   accumulate in memory and are lost on restart, making the dedup window
   session-scoped rather than permanent.
2. all categories (companies, titles, urls) share one growing file with
   no way to expire stale entries.

the replacement uses a directory tree where file existence IS the checksum
record. no load/persist cycle needed.

---

### directory structure

root: `/var/protocol-7/jobsite/checksum-store/`

```
checksum-store/
  companies/
    blacklisted/
      <AMOS-chksum>      ← file exists = this company is blacklisted
  titles/
    <BMW-L13-chksum>     ← file exists = this title was already assessed
  urls/
    <V7EPOCH>/           ← one subdir per V7 epoch (see below)
      <BMW-L13-chksum>   ← file exists = this url was seen in this epoch
```

---

### V7 epoch for url subdirectory names

use `<[base.ntime.epoch_timestamp]>` (no args = current epoch) to get the
epoch string, e.g. `V7L36RY`. strip the leading `V7` to get a 5-char base32
dir name, OR keep the full `V7L36RY` as-is — your choice, but be consistent.

```perl
my $epoch_dir = <[base.ntime.epoch_timestamp]>;   ## e.g. 'V7L36RY'
```

url checksums go into `urls/<epoch_dir>/<chksum>`.

---

### actions to implement

#### check (replaces current check logic)

```perl
if ( $action eq 'check' ) {
    my $job = shift // {};
    my @hits;

    ## company blacklist ##
    if ( length( $job->{'company'} // '' ) ) {
        utf8::encode( my $co = $job->{'company'} );
        my $c_sum = <[chk-sum.amos]>->($co);
        if ( length $c_sum ) {
            push @hits, "company:$c_sum"
                if -e "$store_root/companies/blacklisted/$c_sum";
        }
    }

    ## title dedup ##
    if ( length( $job->{'title'} // '' ) ) {
        utf8::encode( my $ti = $job->{'title'} );
        my $t_sum = <[chk-sum.bmw.str-b32.L13]>->($ti);
        if ( length $t_sum ) {
            push @hits, "title:$t_sum"
                if -e "$store_root/titles/$t_sum";
        }
    }

    ## url dedup : check across all epoch dirs ##
    if ( length( $job->{'url'} // '' ) ) {
        utf8::encode( my $url = $job->{'url'} );
        my $u_sum = <[chk-sum.bmw.str-b32.L13]>->($url);
        if ( length $u_sum ) {
            my $url_root = "$store_root/urls";
            if ( opendir my $dh, $url_root ) {
                for my $epoch_dir ( readdir $dh ) {
                    next if $epoch_dir =~ m{^\.};
                    if ( -e "$url_root/$epoch_dir/$u_sum" ) {
                        push @hits, "url:$u_sum";
                        last;
                    }
                }
                closedir $dh;
            }
        }
    }

    return { 'is_blocked' => scalar(@hits) > 0, 'hits' => \@hits };
}
```

#### add (called after successful assessment)

write title and url checksums to the store. do NOT write company.

```perl
if ( $action eq 'add' ) {
    my $job = shift // {};

    my $epoch_dir = <[base.ntime.epoch_timestamp]>;

    if ( length( $job->{'title'} // '' ) ) {
        utf8::encode( my $ti = $job->{'title'} );
        my $t_sum = <[chk-sum.bmw.str-b32.L13]>->($ti);
        if ( length $t_sum ) {
            <[base.file.make_path]>->("$store_root/titles");
            open my $fh, '>', "$store_root/titles/$t_sum" or ();
            close $fh if $fh;
        }
    }

    if ( length( $job->{'url'} // '' ) ) {
        utf8::encode( my $url = $job->{'url'} );
        my $u_sum = <[chk-sum.bmw.str-b32.L13]>->($url);
        if ( length $u_sum ) {
            <[base.file.make_path]>->("$store_root/urls/$epoch_dir");
            open my $fh, '>', "$store_root/urls/$epoch_dir/$u_sum" or ();
            close $fh if $fh;
        }
    }

    return TRUE;
}
```

#### blacklist_company

```perl
if ( $action eq 'blacklist_company' ) {
    my $company = shift // '';
    return FALSE unless length $company;
    utf8::encode($company) if utf8::is_utf8($company);
    my $c_sum = <[chk-sum.amos]>->($company);
    return FALSE unless length $c_sum;
    <[base.file.make_path]>->("$store_root/companies/blacklisted");
    open my $fh, '>', "$store_root/companies/blacklisted/$c_sum" or return FALSE;
    close $fh;
    return TRUE;
}
```

#### stats

```perl
if ( $action eq 'stats' ) {
    my $co_count = do {
        opendir( my $dh, "$store_root/companies/blacklisted" )
            ? scalar( grep { !/^\./ } readdir $dh )
            : 0;
    };
    my $ti_count = do {
        opendir( my $dh, "$store_root/titles" )
            ? scalar( grep { !/^\./ } readdir $dh )
            : 0;
    };
    my $url_count = 0;
    if ( opendir my $dh, "$store_root/urls" ) {
        for my $ep ( grep { !/^\./ } readdir $dh ) {
            opendir( my $edh, "$store_root/urls/$ep" ) or next;
            $url_count += scalar( grep { !/^\./ } readdir $edh );
        }
    }
    return {
        'companies' => $co_count,
        'titles'    => $ti_count,
        'urls'      => $url_count,
    };
}
```

#### prune (new action — remove old epoch url dirs)

remove url epoch dirs older than `cfg.checksum_store_keep_epochs` epochs
(default 100). call periodically or from `jobsite.cmd.scan`.

```perl
if ( $action eq 'prune' ) {
    my $keep = <jobsite.cfg.checksum_store_keep_epochs> // 100;
    my $current_epoch_num = int( <[base.ntime.epoch_dec]> );
    my $removed = 0;
    my $url_root = "$store_root/urls";
    if ( opendir my $dh, $url_root ) {
        for my $ep_dir ( grep { !/^\./ } readdir $dh ) {
            next unless $ep_dir =~ m{^V7[A-Z2-7]{5}$}i;
            ## decode epoch dir name to integer for comparison ##
            my $ep_num = <[base.ntime.epoch_timestamp]>->($ep_dir);
            next unless defined $ep_num and $ep_num =~ m{^\d+$};
            if ( $current_epoch_num - $ep_num > $keep ) {
                unlink glob("$url_root/$ep_dir/*");
                rmdir "$url_root/$ep_dir";
                $removed++;
            }
        }
        closedir $dh;
    }
    <[base.logs]>->( 1, 'checksum-store prune: removed %d epoch dirs', $removed );
    return $removed;
}
```

#### load / persist

these become no-ops (or migrate stubs). add them as stubs that return
immediately, so existing callers in `jobsite.init_code` and
`jobsite.cmd.blacklist-add` do not break:

```perl
if ( $action eq 'load' )    { return TRUE; }
if ( $action eq 'persist' ) { return TRUE; }
```

---

### migration

on first run, if the old YAML file exists
(`/var/protocol-7/jobsite/checksum-index.yaml`), migrate its `companies`
entries to the new blacklist dir. the yaml file only contains blacklisted
companies (add was never persisted). do this at the top of the module before
the action dispatch:

```perl
my $store_root   = '/var/protocol-7/jobsite/checksum-store';
my $old_yaml     = '/var/protocol-7/jobsite/checksum-index.yaml';
my $migrated_flag = "$store_root/.migrated";

if ( -f $old_yaml and not -f $migrated_flag ) {
    <[base.perlmod.autoload]>->('YAML::XS');
    my $old = eval { YAML::XS::LoadFile($old_yaml) } // {};
    for my $c_sum ( keys %{ $old->{'companies'} // {} } ) {
        <[base.file.make_path]>->("$store_root/companies/blacklisted");
        open my $fh, '>', "$store_root/companies/blacklisted/$c_sum" or next;
        close $fh;
    }
    <[base.file.make_path]>->($store_root);
    open my $fh, '>', $migrated_flag and close $fh;
    <[base.logs]>->( 1, 'checksum-store: migrated old yaml blacklist' );
}
```

---

### module header

```
# name  = jobsite.checksum.index
# descr = filesystem directory-based checksum store for jobsite dedup + blacklist
# note  = file existence = record; no load/persist cycle; epoch dirs for url expiry
```

---

### do not touch

- `jobsite.cmd.blacklist-add` — calls `blacklist_company` then `persist`; both
  will work (persist is now a no-op)
- `jobsite.init_code` — calls `load`; now a no-op, fine
- `jobsite.handler.assess-done` — calls `add`; unchanged API
- `jobsite.dispatch.assessments` — calls `check`; unchanged API

---

## signatures note

this codebase uses AMOS7 data signatures at the end of each module file
(4-line footer starting with `#,,.,,,...`). do NOT manually write or edit
signature lines. existing signatures on modified files will be regenerated
by the signing system. do not add fake/stub signatures to new files.

## dispatch

#,,..,.,.,.,,,.,.,..,,...,...,..,,..,,,,,,,.,,..,,...,...,.,,,,..,...,,,,,.,,,
#3SEQBFVI2GA2QAKMZFTMQWATZZ3X2GXN6FFVFHNUCSLUQZBU437BMVBP52AIVWHS4NKEFZ3UQYVT2
#\\\|FOKXJX6JIGB7DBXVJWN7ONUK76O2WK5AJNBAHFTTBEKC5K2WJWR \ / AMOS7 \ YOURUM ::
#\[7]47XC5NOJU5XJ6GB5DYZWWYR4Q3DLFLQYKOCCD2JDC34CIEDXHCAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
