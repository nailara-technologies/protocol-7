use strict; use warnings; use IO::Socket::UNIX;
my ($cmd) = @ARGV;
my $sock_path = '/var/run/.7/UNIX/NIW7OAQ';
my $auth_user = 'unix-taeki';
my $sock = IO::Socket::UNIX->new(Type=>SOCK_STREAM(), Peer=>$sock_path) or die "connect: $!";
my $banner = <$sock>; chomp $banner if defined $banner;
die "no banner" unless defined $banner and $banner =~ m{^\\PROTOCOL-7-VERSION\\};
print STDERR "banner: $banner\n";
syswrite($sock,"select unix\n"); my $s=<$sock>; chomp $s if defined $s; print STDERR "select: $s\n";
die "select failed" unless defined $s and $s =~ m{^TRUE};
syswrite($sock,"auth $auth_user\n"); my $a=<$sock>; chomp $a if defined $a; print STDERR "auth: $a\n";
die "auth failed" unless defined $a and $a =~ m{^AUTH_TRUE};
syswrite($sock,"$cmd\n");
my $line=<$sock>; chomp $line if defined $line; print STDERR "reply-line: $line\n";
if (defined $line and $line =~ m{^SIZE\s+(\d+)}) {
    my $n=$1; my $buf=''; while(length($buf)<$n){my $r=sysread($sock,my $b,$n-length($buf)); last if !$r; $buf.=$b;}
    $buf =~ s/\n\z//; print "SIZE:$buf\n";
} else {
    print (defined $line ? "$line\n" : "(no reply)\n");
}
close($sock);

#,,,,,.,,,..,,.,,,.,.,.,.,,..,,,,,.,.,,,.,,,,,..,,...,..,,,..,..,,...,..,,.,,,
#VQJMJGP5YZGHFQJGEWALY3AOI6SWD5VDDWSH7XZ74LZF7URLO34CDUFGUYOS4LYCTSUUFEIKZSKR6
#\\\|ORSFDYQTQ6JIR3GE6WPLXEXVC5QCQXECCT4J4625X5A5PBXB47T \ / AMOS7 \ YOURUM ::
#\[7]LUP7BNEXCYJR2B4W3XLCFO5GGKNSLK47LRT6KPRWTM7HTLQWVCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
