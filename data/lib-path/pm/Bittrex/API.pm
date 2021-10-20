package Bittrex::API;

=encoding utf8

=head1 NAME

Bittrex - API wrapper for the L<Bittrex|https://www.bittrex.com> exchange.

=head1 SYNOPSIS

  use Bittrex::API;

  my $bittrex = Bittrex::API->new();
  my $market_data = $bittrex->getmarkets();

  my $account = Bittrex::API->new($apikey, $apisecret);
  my $balances = $bittrex->getbalances();

=cut

use strict;
use warnings;

use Carp;
use JSON;
use LWP::UserAgent;
use URI::Query;
use Digest::SHA qw( hmac_sha512_hex );

# TODO add logging

our $VERSION = '1.0';

use constant {
  APIROOT => 'https://bittrex.com/api/v1.1'
};

=head1 DESCRIPTION

This is a basic wrapper for the Bittrex API. It will handle API signing using
your specific API keys. All information is exchanged directly with the Bittrex
API service using a secure HTTPS connections.

Unless otherwise specifically stated, each method returns the decoded JSON
object in the C<result> field of the response. If a call fails, the method
returns C<undef>.

Bittrex is a leading cryptocurrency exchange for buying & selling digital
currency. This software assumes no risk and makes no guarantees of performance
on any trades. Any examples provided here are for reference only and do not
imply any recommendations for investment strategies.

Full API documentation can be found here: L<https://bittrex.com/Home/Api>.

This module is current as of API version 1.1.

=head2 Methods

=over

=cut

################################################################################
=item B<new($my_key, $my_secret)>

The key and secret must be registered to your account under API keys. Be sure
to set appropriate permissions based on the actions you intend to perform.
Public actions do not require these values.

=cut

#---------------------------------------
sub new {
  my $class = shift;
  my ($key, $secret) = @_;

  my $ua = LWP::UserAgent->new();

  my $self = {
    key => $key,
    secret => $secret,
    client => $ua
  };

  bless $self, $class;
}

################################################################################
sub _public_query {
  my $self = shift;
  my ($path, $params) = @_;

  my $json = $self->_get($path, $params);

  return _standard_result($json);
}

################################################################################
sub _signed_query {
  my $self = shift;
  my ($path, $params) = @_;

  my $json = $self->_get($path, $params);

  return _standard_result($json);
}

################################################################################
# TODO move signing function into appropriate query
sub _get {
  my $self = shift;
  my ($path, $params) = @_;

  # setup for api key signature
  if (defined $self->{key}) {
    $params->{nonce} = time;
    $params->{apikey} = $self->{key};
  }

  # build the request
  my $qq = URI::Query->new($params);
  my $uri = APIROOT . "$path?$qq";
  my $apisign = $self->_apisign($uri);

  my $client = $self->{client};
  my $resp = $client->get($uri, apisign => $apisign);

  unless ($resp->is_success) {
    carp $resp->status_line;
    return undef;
  }

  # TODO improve error handling
  return decode_json $resp->decoded_content;
}

################################################################################
sub _standard_result {
  my ($json) = @_;

  unless ($json) {
    carp 'no data in response';
    return undef;
  }

  unless ($json->{success}) {
    carp $json->{message};
    return undef;
  }

  my $result = $json->{result};

  # if the results are an array, return appropriately
  return (ref($result) eq 'ARRAY') ? @{ $result } : $result
}

################################################################################
sub _apisign {
  my $self = shift;
  my ($uri) = @_;

  # XXX this isn't entirely awesome... it would be nice if there was a way to
  # include the query parameters in this method rather than handling them in
  # another part of the method. not terrible, just seems like it would be more
  # elegant to put all authentication / signing in the same place.

  unless (defined $self->{secret}) {
    return '';
  }

  hmac_sha512_hex($uri, $self->{secret});
}

################################################################################
=item B<getmarkets()>

Used to get the open and available trading markets at Bittrex along with other metadata.

=cut

#---------------------------------------
sub getmarkets {
  my $self = shift;
  return $self->_public_query('/public/getmarkets');
}

################################################################################
=item B<getcurrencies()>

Used to get all supported currencies at Bittrex along with other metadata.

=cut

#---------------------------------------
sub getcurrencies {
  my $self = shift;
  return $self->_public_query('/public/getcurrencies');
}

################################################################################
=item B<getmarketsummaries()>

Used to get the last 24 hour summary of all active exchanges.

=cut

#---------------------------------------
sub getmarketsummaries {
  my $self = shift;
  return $self->_public_query('/public/getmarketsummaries');
}

################################################################################
=item B<getticker($market)>

Used to get the current tick values for a market.

C<market> : (required) a string literal for the market (ex: BTC-LTC)

=cut

#---------------------------------------
sub getticker {
  my $self = shift;
  my ($market) = @_;

  return $self->_public_query('/public/getticker', {
    market => $market
  });
}

################################################################################
=item B<getmarketsummary($market)>

Used to get the last 24 hour summary of a specified exchange.

C<market> : (required) a string literal for the market (ex: BTC-LTC)

=cut

#---------------------------------------
sub getmarketsummary {
  my $self = shift;
  my ($market) = @_;

  my $json = $self->_get('/public/getmarketsummary', {
    market => $market
  });

  # the result comes back as an array with a single element...
  # peel it back to help the caller out

  my @ret = _standard_result($json);
  unless (@ret) { return undef };

  return $ret[0];
}

################################################################################
=item B<getorderbook($market, $type, $depth)>

Used to get retrieve the orderbook for a given market

C<market> : (required) a string literal for the market (ex: BTC-LTC)
C<type> : (optional) buy, sell or both to identify the type of order book (default: both)
C<depth> : (optional) how deep of an order book to retrieve (default: 20, max: 50)

=cut

#---------------------------------------
sub getorderbook {
  my $self = shift;
  my ($market, $type, $depth) = @_;

  return $self->_public_query('/public/getorderbook', {
    market => $market,
    type => $type
  });
}

################################################################################
=item B<getmarkethistory($market)>

Used to retrieve the latest trades that have occured for a specific market.

C<market> : (required) a string literal for the market (ex: BTC-LTC)

=cut

#---------------------------------------
sub getmarkethistory {
  my $self = shift;
  my ($market) = @_;

  return $self->_public_query('/public/getmarkethistory', {
    market => $market
  });
}

################################################################################
# TODO add convenience methd to buy at market value
=item B<buylimit($market, $quantity, $rate)>

Used to place a buy-limit order in a specific market. Make sure you have the
proper permissions set on your API keys for this call to work.

On success, returns the UUID of the order.

C<market> (required) a string literal for the market (ex: BTC-LTC)
C<quantity> (required) the amount to purchase
C<rate> (required) the rate at which to place the order.

=cut

#---------------------------------------
sub buylimit {
  my $self = shift;
  my ($market, $qty, $rate) = @_;

  my $ret = $self->_signed_query('/market/buylimit', {
    market => $market,
    quantity => $qty,
    rate => $rate
  });

  # return just the UUID, not the wrapper
  return ($ret) ? $ret->{uuid} : undef;
}

################################################################################
# TODO add convenience methd to sell at market value
=item B<selllimit($market, $quantity, $rate)>

Used to place a sell-limit order in a specific market. Make sure you have the
proper permissions set on your API keys for this call to work.

On success, returns the UUID of the order.

C<market> (required) a string literal for the market (ex: BTC-LTC)
C<quantity> (required) the amount to purchase
C<rate> (required) the rate at which to place the order.

=cut

#---------------------------------------
sub selllimit {
  my $self = shift;
  my ($market, $qty, $rate) = @_;

  my $ret = $self->_signed_query('/market/selllimit', {
    market => $market,
    quantity => $qty,
    rate => $rate
  });

  # return just the UUID, not the wrapper
  return ($ret) ? $ret->{uuid} : undef;
}

################################################################################
=item B<cancel($uuid)>

Used to cancel a buy or sell order.

C<uuid> (required) uuid of buy or sell order

=cut

#---------------------------------------
sub cancel {
  my $self = shift;
  my ($uuid) = @_;

  my $json = $self->_get('/market/cancel', {
    uuid => $uuid
  });

  unless ($json->{success}) {
    carp $json->{message};
    return undef;
  }

  return 1;
}

################################################################################
=item B<getopenorders($market)>

Get all orders that you currently have opened. A specific market can be requested.

C<market> (optional) a string literal for the market (ex: BTC-LTC)

=cut

#---------------------------------------
sub getopenorders {
  my $self = shift;
  my ($market) = @_;

  return $self->_signed_query('/market/getopenorders', {
    market => $market
  });
}

################################################################################
=item B<getbalances()>

Used to retrieve all balances from your account.

=cut

#---------------------------------------
sub getbalances {
  my $self = shift;
  return $self->_signed_query('/account/getbalances');
}

################################################################################
=item B<getbalance($currency)>

Used to retrieve the balance from your account for a specific currency.

C<currency> : (required) a string literal for the currency (ex: LTC)

=cut

#---------------------------------------
sub getbalance {
  my $self = shift;
  my ($currency) = @_;

  return $self->_signed_query('/account/getbalance', {
    currency => $currency
  });
}

################################################################################
=item B<getdepositaddress($currency)>

Used to retrieve or generate an address for a specific currency. If one does not
exist, the call will fail and return -1 until one is available.

On success, returns the deposit address as a string.

C<currency> : (required) a string literal for the currency (ex: LTC)

=cut

#---------------------------------------
sub getdepositaddress {
  my $self = shift;
  my ($currency) = @_;

  # we need the full response to examine the 'message' field
  my $json = $self->_get('/account/getdepositaddress', {
    currency => $currency
  });

  # first check to see if the address is being generated...
  if ($json->{message} eq 'ADDRESS_GENERATING') {
    return -1;
  }

  # bail out if the call failed
  unless ($json->{success}) {
    carp $json->{message};
    return undef;
  }

  my $result = $json->{result};

  # just some sanity checking...
  unless ($result->{Currency} eq $currency) {
    carp 'returned currency did not match';
    return undef;
  }

  return $result->{Address};
}

################################################################################
=item B<withdraw($currency, $quantity, $address, $paymentid)>

Used to withdraw funds from your account. note: please account for txfee.

On success, returns the withdrawal UUID as a string.

C<currency> (required) a string literal for the currency (ie. BTC)
C<quantity> (required) the quantity of coins to withdraw
C<address> (required) the address where to send the funds.
C<paymentid> (optional) required for some currencies (memo/tag/etc)

=cut

#---------------------------------------
sub withdraw {
  my $self = shift;
  my ($currency, $qty, $address, $memo) = @_;

  my $ret = $self->_signed_query('/account/withdraw', {
    currency => $currency,
    quantity => $qty,
    address => $address,
    paymentid => $memo
  });

  # return just the UUID, not the wrapper
  return ($ret) ? $ret->{uuid} : undef;
}

################################################################################
=item B<getorder($uuid)>

Used to retrieve a single order by uuid.

C<uuid> (required) the uuid of the buy or sell order

=cut

#---------------------------------------
sub getorder {
  my $self = shift;
  my ($uuid) = @_;

  return $self->_signed_query('/account/getorder', {
    uuid => $uuid
  });
}

################################################################################
=item B<getorderhistory($market)>

Used to retrieve your order history.

C<market> (optional) a string literal for the market (ie. BTC-LTC). If ommited, will return for all markets

=cut

#---------------------------------------
sub getorderhistory {
  my $self = shift;
  my ($market) = @_;

  return $self->_signed_query('/account/getorderhistory', {
    market => $market
  });
}

################################################################################
=item B<getwithdrawalhistory($currency)>

Used to retrieve your withdrawal history.

C<currency> (optional) a string literal for the currecy (ie. BTC). If omitted, will return for all currencies

=cut

#---------------------------------------
sub getwithdrawalhistory {
  my $self = shift;
  my ($currency) = @_;

  return $self->_signed_query('/account/getwithdrawalhistory', {
    currency => $currency
  });
}

################################################################################
=item B<getdeposithistory($currency)>

Used to retrieve your deposit history.

C<currency> (optional) a string literal for the currecy (ie. BTC). If omitted, will return for all currencies

=cut

#---------------------------------------
sub getdeposithistory {
  my $self = shift;
  my ($currency) = @_;

  return $self->_signed_query('/account/getdeposithistory', {
    currency => $currency
  });
}

1;  ## EOM
################################################################################

=back

=head1 AUTHOR

Developed and maintained by L<jheddings|https://github.com/jheddings>.

Tips are always appreciated!

=over

=item BTC - C<1K6mkumfqTQTF4HJuLZAh1g8uRHQhWLomz>

=item ETH - C<0xA114CE80Fc995a993d5726a74DAf08ad8C739Af4>

=item DASH - C<XmTsc9qQQctrauq8zVXXoL9c8DKd29q2Gd>

=item LTC - C<LLscXRCUndQRjQdbTouvDE9NH5fiaanZzo>

=back

=head1 COPYRIGHT

Copyright (c) 2017 Jason Heddings

Licensed under the terms of the L<MIT License|https://opensource.org/licenses/MIT>,
which is also included in the original L<source code|https://github.com/jheddings/bittrex>
of this project.

=cut

#,,,.,.,,,,..,,.,,,..,,..,,..,,..,.,.,,,.,...,.,.,...,...,,..,,.,,,.,,.,,,..,,
#5TFPRDYOJAQ3TJICQFT6HI4FIE442U6WJP7W3BBR3N2STQPPMBEQ6N245XIDYBIFPVAMTWPNWMLXU
#\\\|FLA64BR65L22UM6Y5TOVZIO42FMCJ6CV4KY2OLODZJVO6RUN3SK \ / AMOS7 \ YOURUM ::
#\[7]HFS6LKYWQAL6P76TOBHSARUXLGRF2776KR2RGURESLBHSTWMFADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
