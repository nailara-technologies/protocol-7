use strict; use warnings;
our %code;
my %CONST = (QTDIR=>0x80, DMDIR=>0x80000000);
sub P9C { $CONST{$_[0]} }
%code = (
  'plan-9.protocol.codec.encode-uint64' => sub { pack('Q<',$_[0]) },
  'plan-9.protocol.codec.encode-string' => sub { my $s=shift//''; pack('v',length $s).$s },
  'plan-9.protocol.codec.encode-qid'    => sub { my($t,$v,$p)=@_; pack('C V Q<',$t,$v,$p) },
  'base.ntime' => sub { time },
);
sub load_mod {
  my ($name)=@_;
  open(my $fh,'<',"/data/projects/protocol-7/src/$name") or die $!;
  my $src=do{local $/;<$fh>}; close $fh;
  $src =~ s/\n#,.*\z//s;
  $src =~ s/<plan-9\.protocol\.constants\.(\w+)>/P9C('$1')/g;
  $src =~ s/<\[([\w.\-]+)\]>/\$code{'$1'}/g;
  $src =~ s/\@ARG/\@_/g;
  my $cref = eval "sub { $src }"; die "$name: $@" if $@;
  $code{$name}=$cref;
}
load_mod('plan-9.protocol.codec.encode-stat');
my $stat = { type=>0, dev=>0, qid_type=>0x80, qid_version=>0, qid_path=>5,
  mode=>0755|0x80000000, atime=>100, mtime=>100, length=>0,
  name=>'term-alpha', uid=>'root', gid=>'root', muid=>'root' };
my $real = $code{'plan-9.protocol.codec.encode-stat'}->($stat);
my $mine = pack('v',0).pack('v',0).pack('V',0).pack('C V Q<',0x80,0,5)
  .pack('V',0755|0x80000000).pack('V',100).pack('V',100).pack('Q<',0)
  .pack('v',10).'term-alpha'.pack('v',4).'root'.pack('v',4).'root'.pack('v',4).'root';
substr($mine,0,2)=pack('v',length($mine)-2);
print "real len=",length($real)," mine len=",length($mine),"\n";
print "identical: ", ($real eq $mine ? "YES":"NO"), "\n";
print "real: ", unpack("H*",$real), "\n";
print "mine: ", unpack("H*",$mine), "\n";
# parse as readdir does
my $size = unpack('v',substr($real,0,2));
my $sd = substr($real,2,$size);
print "stat_size=$size sd_len=",length($sd),"\n";
my $name_pos = 2+4+13+4+4+4+8;
my $nl = unpack('v', substr($sd,$name_pos,2));
print "name_len at 39: $nl, name: ", substr($sd,$name_pos+2,$nl), "\n";

#,,,.,.,,,...,...,.,,,...,.,.,,,,,,.,,...,.,.,..,,...,...,,.,,.,,,,..,.,.,.,.,
#MT3IIMSQO3ID5O2NICY7J26U6YMYK22JZ7QHSNNVELV3WEVOSXRSTGOJ5YTW3WJR4I2GWUYEUZNIM
#\\\|7WYVNHJDRRKENEOOZNY36GDPIVOZSIPEBOGJIUH6T2ZSJ237IG3 \ / AMOS7 \ YOURUM ::
#\[7]Y5YLE6ZTFM5W4HPMHFVHPUCJOJU2K5F7YTT5U6DVSSBLYKZVUMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
