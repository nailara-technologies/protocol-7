use strict; use warnings; use IO::Socket::INET; $|=1;
our %data; our %code;
my $PORT=15644;
my %CONST=(Tversion=>100,Rversion=>101,Tattach=>104,Rattach=>105,Rerror=>107,Twalk=>110,Rwalk=>111,Topen=>112,Ropen=>113,Tread=>116,Rread=>117,Twrite=>118,Tclunk=>120,Rclunk=>121,Tstat=>124,Rstat=>125,DMDIR=>0x80000000,QTDIR=>0x80,QTFILE=>0);
sub P9C { $CONST{+shift} // die "const $_[0]" }
%code=(
 'plan-9.protocol.codec.encode-uint8'=>sub{pack('C',$_[0])},
 'plan-9.protocol.codec.encode-uint16'=>sub{pack('v',$_[0])},
 'plan-9.protocol.codec.encode-uint32'=>sub{pack('V',$_[0])},
 'plan-9.protocol.codec.encode-uint64'=>sub{pack('Q<',$_[0])},
 'plan-9.protocol.codec.decode-uint8'=>sub{unpack('C',$_[0])},
 'plan-9.protocol.codec.decode-uint16'=>sub{unpack('v',$_[0])},
 'plan-9.protocol.codec.decode-uint32'=>sub{unpack('V',$_[0])},
 'plan-9.protocol.codec.decode-uint64'=>sub{unpack('Q<',$_[0])},
 'plan-9.protocol.codec.encode-string'=>sub{my $s=shift//'';pack('v',length $s).$s},
 'plan-9.protocol.codec.decode-string'=>sub{my $l=unpack('v',substr($_[0],0,2));(substr($_[0],2,$l),substr($_[0],2+$l))},
 'plan-9.protocol.codec.encode-qid'=>sub{my($t,$v,$p)=@_;pack('C V Q<',$t,$v,$p)},
 'plan-9.protocol.codec.decode-qid'=>sub{unpack('C V Q<',$_[0])},
 'plan-9.protocol.codec.encode-message'=>sub{my($t,$g,$b)=@_;pack('V C v',7+length($b),$t,$g).$b},
 'base.logs'=>sub{1}, 'base.ntime'=>sub{time},
);
sub load_mod { my($n)=@_; open(my $fh,'<',"/data/projects/protocol-7/src/$n") or die; my $s=do{local $/;<$fh>}; close $fh;
 $s=~s/\n#,.*\z//s; $s=~s/<plan-9\.protocol\.constants\.(\w+)>/P9C('$1')/g; $s=~s/<\[([\w.\-]+)\]>/\$code{'$1'}/g; $s=~s/\@ARG/\@_/g;
 my $c=eval "sub { $s }"; die "$n: $@" if $@; $code{$n}=$c; }
load_mod($_) for qw|storage.9p.connect storage.9p.version storage.9p.attach storage.9p.walk storage.9p.open storage.9p.readdir storage.9p.clunk storage.9p.read-message
 plan-9.protocol.error plan-9.protocol.codec.encode-stat plan-9.server.handle_version plan-9.server.handle_attach plan-9.server.handle_walk plan-9.server.handle_request
 plan-9.server.handle-io-open plan-9.server.handle-io-read plan-9.server.handle-io-stat plan-9.server.handle-io-clunk
 plan-9.server.buffer-stat plan-9.server.buffer-read-root-dir plan-9.server.buffer-read-buffer-dir plan-9.server.buffer-read-layer plan-9.server.buffer-read-metadata plan-9.server.export_buffer|;
my $win={session_id=>'AAA',created=>time,buffer=>{width=>80,height=>24,depth=>13,layer_size=>64,layers=>[map{"l$_\n"}0..12]}};
$code{'plan-9.server.export_buffer'}->($win,'term-alpha');
my $listen=IO::Socket::INET->new(LocalAddr=>'127.0.0.1',LocalPort=>$PORT,Proto=>'tcp',Listen=>5,ReuseAddr=>1) or die;
my $pid=fork(); die unless defined $pid;
if($pid==0){ $SIG{CHLD}='IGNORE';
 while(my $sock=$listen->accept()){ my $cp=fork(); next if !defined $cp; if($cp){close $sock;next;} close $listen;
  my $client={fids=>{},msize=>8192,socket=>$sock};
  while(1){ my $hdr=''; while(length($hdr)<4){my $n=sysread($sock,my $b,4-length($hdr)); last if !$n; $hdr.=$b;} last if length($hdr)<4;
   my $size=unpack('V',$hdr); my $body=''; while(length($body)<$size-4){my $n=sysread($sock,my $b,$size-4-length($body)); last if !$n; $body.=$b;} last if length($body)<$size-4;
   my($type,$tag)=unpack('C v',substr($body,0,3)); my $data=substr($body,3);
   my $resp=$code{'plan-9.server.handle_request'}->($client,0,$type,$tag,$data);
   syswrite($sock,$resp) if defined $resp; }
  close $sock; exit 0; }
 exit 0; }
sleep 1;
my $res=$code{'storage.9p.connect'}->({host=>'127.0.0.1',port=>$PORT,name=>'d'});
print "connect: $res->{mode} $res->{data}\n";
my $conn=$data{'storage'}{'9p'}{'connections'}{'d'};
# manual tread on fid 0 to see raw bytes
$code{'storage.9p.open'}->($conn,0,0);
my $tag=++$conn->{tag} & 0xFFFF;
my $req=$code{'plan-9.protocol.codec.encode-uint32'}->(0).$code{'plan-9.protocol.codec.encode-uint64'}->(0).$code{'plan-9.protocol.codec.encode-uint32'}->(8168);
$conn->{socket}->send($code{'plan-9.protocol.codec.encode-message'}->($CONST{Tread},$tag,$req));
my $r=$code{'storage.9p.read-message'}->($conn,$tag);
print "read resp mode=$r->{mode}\n";
my $d=$r->{data};
my $len=unpack('V',substr($d,0,4));
print "count=$len body-avail=",length($d)-4,"\n";
print "hex: ",unpack("H*",substr($d,4,80)),"\n";
my $c=substr($d,4,$len);
my $ss=unpack('v',substr($c,0,2));
print "first entry stat_size=$ss\n";
my $sd=substr($c,2,$ss);
print "sd_len=",length($sd)," name_len\@39=",unpack('v',substr($sd,39,2))," name='",substr($sd,41,unpack('v',substr($sd,39,2))),"'\n";
$res=$code{'storage.9p.readdir'}->($conn,0);
print "readdir entries: [",join(",",@{$res->{data}}),"]\n";
kill 9,$pid; waitpid($pid,0);

#,,.,,..,,,.,,..,,...,.,,,.,,,...,.,.,..,,.,,,..,,...,...,..,,,..,.,,,..,,.,,,
#MAATGSHNPY5VZJCK6NT6TPEWWM4TP7YMEISD5FB2B3DMNOXABJSKTHT25YYRYNYP5246MGATM366I
#\\\|ZDBXHFHJW6WSKW5JDF4LITDLGDJX6IOW3KZGISXJLXGP74QQQ6W \ / AMOS7 \ YOURUM ::
#\[7]5PC54DKD6Y2AD74GWSUSTHDQ5UPBLMKDKS7EGJWRKAIVRCX2TAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
