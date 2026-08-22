use strict; use warnings; use IO::Socket::INET;
my $listen = IO::Socket::INET->new(LocalAddr=>'127.0.0.1',LocalPort=>15642,Proto=>'tcp',Listen=>5,ReuseAddr=>1) or die "listen: $!";
my $pid = fork(); die unless defined $pid;
if ($pid==0) {
    warn "child: waiting accept\n";
    my $client = $listen->accept();
    warn "child: accepted\n";
    my $hdr='';
    while (length($hdr)<4) { my $n=sysread($client,my $b,4-length($hdr)); warn "child: sysread hdr n=".($n//'undef')."\n"; last if !$n; $hdr.=$b; }
    my $size=unpack('V',$hdr); warn "child: size=$size\n";
    my $body='';
    while (length($body)<$size-4) { my $n=sysread($client,my $b,$size-4-length($body)); last if !$n; $body.=$b; }
    warn "child: body=".length($body)."\n";
    my ($type,$tag)=unpack('C v',substr($body,0,3));
    warn "child: type=$type tag=$tag\n";
    my $r = pack('V',8192).pack('v',6).'9P2000';
    my $m = pack('V C v',7+length($r),101,$tag).$r;
    syswrite($client,$m);
    warn "child: replied\n";
    sleep 5; exit 0;
}
sleep 1;
warn "parent: loading module\n";
our %code;
$code{'plan-9.protocol.codec.encode-uint32'}=sub{pack('V',$_[0])};
$code{'plan-9.protocol.codec.encode-string'}=sub{my $s=shift//'';pack('v',length $s).$s};
$code{'plan-9.protocol.codec.encode-message'}=sub{my($t,$g,$b)=@_;pack('V C v',7+length($b),$t,$g).$b};
$code{'plan-9.protocol.codec.decode-uint32'}=sub{unpack('V',$_[0])};
$code{'plan-9.protocol.codec.decode-uint16'}=sub{unpack('v',$_[0])};
$code{'plan-9.protocol.codec.decode-uint8'}=sub{unpack('C',$_[0])};
$code{'plan-9.protocol.codec.decode-string'}=sub{my $l=unpack('v',substr($_[0],0,2));(substr($_[0],2,$l),substr($_[0],2+$l))};
$code{'base.logs'}=sub{1};
sub P9C { my %c=(Tversion=>100,Rerror=>107); $c{$_[0]} }
open(my $fh,'<','/data/projects/protocol-7/src/storage.9p.version'); my $src=do{local $/;<$fh>}; close $fh;
$src =~ s/\n#,.*\z//s;
$src =~ s/<plan-9\.protocol\.constants\.(\w+)>/P9C('$1')/g;
$src =~ s/<\[([\w.\-]+)\]>/\$code{'$1'}/g;
$src =~ s/\@ARG/\@_/g;
my $cref = eval "sub { $src }"; die $@ if $@;
warn "parent: module compiled\n";
my $sock = IO::Socket::INET->new(PeerAddr=>'127.0.0.1',PeerPort=>15642,Proto=>'tcp',Timeout=>5) or die "connect $!";
warn "parent: connected\n";
my $conn = { socket=>$sock, tag=>0 };
# inline read-message
my $rm = sub {
    my ($conn,$etag)=@_;
    my $socket=$conn->{socket}; my $header='';
    while (length($header)<4){ my $buf=''; my $n=$socket->sysread($buf,4-length($header)); return {mode=>'false',data=>'closed'} if !defined $n or $n==0; $header.=$buf; }
    my $size=unpack('V',$header); my $body='';
    while (length($body)<$size-4){ my $buf=''; my $n=$socket->sysread($buf,$size-4-length($body)); return {mode=>'false',data=>'closed'} if !defined $n or $n==0; $body.=$buf; }
    return {mode=>'true',data=>substr($body,3)};
};
$code{'storage.9p.read-message'}=$rm;
my $res = $cref->($conn);
warn "parent: version result mode=$res->{mode} data=".( $res->{data}//'' )."\n";
kill 9,$pid; waitpid($pid,0);

#,,.,,...,.,.,...,,,.,,,,,...,.,.,,,,,,.,,...,..,,...,...,.,,,..,,.,.,.,,,..,,
#APAPQZNPLSYFFNXTHMWXOCK3M4NGUBC7GTFN5PRRL56MVDEBO2NR45YK6FH7AZCAQHOHPPNFHYSZS
#\\\|J6DH7JFKBJ6SYZXJALFOOVLY46AMMFT644ZDFIIZ7NWLUS7URYD \ / AMOS7 \ YOURUM ::
#\[7]SZKQBFOIZZ55H7T3256MFJBPYGB26TF2ZYHZSJTOOJKWL6DDIEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
