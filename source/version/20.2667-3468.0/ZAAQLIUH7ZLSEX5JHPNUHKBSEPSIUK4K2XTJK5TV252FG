# >:]

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str = $$call{'args'};  # LLL: implement parameter quoting instead of '!'

return { 'mode' => 'nak', 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
return { 'mode' => 'nak', 'data' => 'requested command matches blacklist!' }
    if $cmd_str =~ m,^\!?(run|hook|subprocess),;

push( @{<mpv.reply_ids>}, $$call{'reply_id'} );
push( @{<mpv.command.reply>}, { 'handler' => 'mpv.handler.pipe.command' } );

if ( $cmd_str !~ s/^\!// ) {
    <[mpv.send_command]>->( split / +/, $cmd_str );
} else {
    <[mpv.send_command]>->( split / +/, $cmd_str, 2 ); # i.e. !show-text foo bar
}

return { 'mode' => 'deferred' };

# ______________________________________________________________________________
#\\URW2Y6HMBIYJ2NZMX5CQFTOUONN2CNAD2XWZSMWPDXTAK6B3KQDQ7CR4QGHIFISDBZ5GN7DOXTTHO
# \\ TO4KS2YGCWIFHDTQWCQDG2TJ46DYEVXGIQGYXIXEL7GMNQW4GGL6 \\// C25519-BASE-32 //
#  \\// XKOS5Y4WU2SAURF3RNPI7BRFILQMLFBWBYQR7AQUWHPPXWNZGAY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
