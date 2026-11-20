package UDT::Simple;

use v5.32.0;
use strict;
use warnings;
use Cwd            qw| abs_path |;
use Exporter       qw| import |;
use File::Basename qw| dirname |;
use File::Path     qw| make_path |;
use Inline;

our @EXPORT_OK = qw|
    startup cleanup socket bind listen accept connect send recv close
    last_error last_error_code perfmon
    |;

my $root_dir = dirname( dirname( dirname( abs_path(__FILE__) ) ) );
make_path("$root_dir/.inline") if not -d "$root_dir/.inline";

my $c_source = <<'END_C';
#include <udt.h>
#include <arpa/inet.h>
#include <string.h>

extern "C" {

static struct sockaddr_in p7_loopback_address(int port) {
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    return address;
}

int p7_startup() {
    return UDT::startup();
}

int p7_cleanup() {
    return UDT::cleanup();
}

int p7_socket() {
    return UDT::socket(AF_INET, SOCK_STREAM, 0);
}

int p7_bind(int socket_handle, int port) {
    struct sockaddr_in address = p7_loopback_address(port);
    return UDT::bind(socket_handle, (struct sockaddr*)&address,
        sizeof(address));
}

int p7_listen(int socket_handle, int backlog) {
    return UDT::listen(socket_handle, backlog);
}

int p7_accept(int socket_handle) {
    return UDT::accept(socket_handle, NULL, NULL);
}

int p7_connect(int socket_handle, int port) {
    struct sockaddr_in address = p7_loopback_address(port);
    return UDT::connect(socket_handle, (struct sockaddr*)&address,
        sizeof(address));
}

int p7_send(int socket_handle, SV* buffer) {
    STRLEN length;
    char* data = SvPV(buffer, length);
    return UDT::send(socket_handle, data, (int)length, 0);
}

int p7_recv(int socket_handle, SV* buffer, int wanted) {
    char* data;
    int received;
    Newx(data, wanted, char);
    received = UDT::recv(socket_handle, data, wanted, 0);
    if (received > 0)
        sv_setpvn(buffer, data, received);
    else
        sv_setpvn(buffer, "", 0);
    Safefree(data);
    return received;
}

int p7_close(int socket_handle) {
    return UDT::close(socket_handle);
}

int p7_last_error_code() {
    return UDT::getlasterror_code();
}

char* p7_last_error() {
    return (char*)UDT::getlasterror_desc();
}

int p7_perfmon(int socket_handle, HV* counters) {
    UDT::TRACEINFO trace;
    int status = UDT::perfmon(socket_handle, &trace, false);
    if (status == UDT::ERROR)
        return status;
    hv_store(counters, "rtt_ms", 6, newSVnv(trace.msRTT), 0);
    hv_store(counters, "send_rate_mbps", 14,
        newSVnv(trace.mbpsSendRate), 0);
    hv_store(counters, "send_loss_total", 15,
        newSViv(trace.pktSndLossTotal), 0);
    hv_store(counters, "recv_loss_total", 15,
        newSViv(trace.pktRcvLossTotal), 0);
    hv_store(counters, "retransmits_total", 17,
        newSViv(trace.pktRetransTotal), 0);
    return status;
}

}

END_C

Inline->bind(
    C           => $c_source,
    name        => 'UDT::Simple',
    directory   => "$root_dir/.inline",
    CC          => 'g++',
    INC         => '-I/usr/include/udt',
    LIBS        => '-ludt -lstdc++',
    BUILD_NOISY => $ENV{'UDT_BUILD_NOISY'} // 0,
);

sub startup         { return p7_startup(@_); }
sub cleanup         { return p7_cleanup(@_); }
sub socket          { return p7_socket(@_); }
sub bind            { return p7_bind(@_); }
sub listen          { return p7_listen(@_); }
sub accept          { return p7_accept(@_); }
sub connect         { return p7_connect(@_); }
sub send            { return p7_send(@_); }
sub recv            { return p7_recv(@_); }
sub close           { return p7_close(@_); }
sub last_error      { return p7_last_error(@_); }
sub last_error_code { return p7_last_error_code(@_); }
sub perfmon         { return p7_perfmon(@_); }

1;

#,,..,.,,,,.,,.,,,,,.,,,.,,,,,.,.,..,,,..,,..,..,,...,...,...,..,,,,,,...,,,.,
#D6QPCBILCLPVE3L6ZSLWQALNYGKX32UVDYNSG4REU3S6ADH53UFFTTOBIVQS4D2XYZDQ7RPMGWBKK
#\\\|MQIHZOWZBZV3I2AA6QCPMWSCV7TMBDUID7LJB352RYNEEKWXM33 \ / AMOS7 \ YOURUM ::
#\[7]LSW3OUMASNJLIMYOJD2ETUOVLSCCL5E42APGJM5JT6SETQJOO2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
