#!/usr/bin/perl
use strict;
use warnings;
$/ = undef;

( my $path = qx(pwd) ) =~ s/\n$//;
die "\n  [!] not in the module directory, aborted [!]\n\n"
    if $path !~ m|/nailara/modules$|;

opendir( my $parse_dir, '.' ) or die $!;

while ( readdir($parse_dir) ) {
    next if $_ =~ /^\./;

    open( my $fh, "<$path/$_" ) or die $!;
    my $content = <$fh>;
    close($fh);

    next if not defined $content;

    my $matched = 0;

    ## part 1 # XXX: incomplete -> [foo.bar] missing...
# $matched=1 if $content =~ s|(?<!\\)\[(\w+\.[\w\.]+?):(.*?)(?<!\\)\]|my$k=$1;my$p=$2;$p=~s/\\\[/[/g;$p=~s/\\\]/]/g;$p=~s/^\s+//;"\$code{'$k'}->($p)"|sge;

#part 2
#    $matched=1 if $content =~ s|\&{ *\$code{'([a-zA-Z0-9_\.]+)'}\s*}\s*\(|<[$1]>->(|sg;
#    $matched=1 if $content =~ s|\$code{'([a-zA-Z0-9_\.]+)'}\s*|<[$1]>|sg;
#    $content =~ s|(<\[[a-zA-Z0-9_\.]+\]>)\s*->\s*\(\s*\)|$1|sg if $matched;
#    $content =~ s|\&{ *(<\[[a-zA-Z0-9_\.]+\]>) *}|$1|sg if $matched;

    print "\n  .:[ $_ ]:.\n\n" . "$content" if $matched;

    $matched = 0;    # writing disabled
    if ($matched) {
        open( my $fh2, ">$path/$_" ) or die $!;
        print {$fh2} $content;
        close($fh2);
    }

}
