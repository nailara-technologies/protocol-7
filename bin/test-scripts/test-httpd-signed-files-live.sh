#!/usr/bin/env bash
set -euo pipefail

ROOT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BASE_URL=${P7_HTTP_URL:-http://127.0.0.1}
HTTP_HOST=${P7_HTTP_HOST:-default.v7.ax}
SITE_DIR=${P7_HTTP_ROOT:-$ROOT_PATH/data/web-root/vhosts/default}
SMALL_FIXTURE=$ROOT_PATH/src/httpd.parse_range_header
LARGE_FIXTURE=${P7_LARGE_SIGNED_FIXTURE:-$ROOT_PATH/data/web-root/vhosts/jobsite.vhost/index.html}
PREFIX=p7-signed-live-$$
SIGNED_NAME=$PREFIX-signed.html
UNSIGNED_NAME=$PREFIX-unsigned.html
TAMPERED_NAME=$PREFIX-tampered.html
LARGE_NAME=$PREFIX-large.html
TMP_DIR=$(mktemp -d /tmp/p7-httpd-signed-live.XXXXXXXX)

cleanup() {
    rm -f -- "$SITE_DIR/$SIGNED_NAME" "$SITE_DIR/$UNSIGNED_NAME" \
        "$SITE_DIR/$TAMPERED_NAME" "$SITE_DIR/$LARGE_NAME"
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    printf 'FAIL : %s\n' "$*" >&2
    exit 1
}

assert_equal() {
    local expected=$1 actual=$2 label=$3
    [[ $actual == "$expected" ]] \
        || fail "$label [ expected '$expected', got '$actual' ]"
    printf 'ok   : %s\n' "$label"
}

request() {
    local name=$1
    shift
    HEADER_FILE=$TMP_DIR/$name.headers
    BODY_FILE=$TMP_DIR/$name.body
    HTTP_CODE=$(curl --max-time 20 -sS -D "$HEADER_FILE" -o "$BODY_FILE" \
        -w '%{http_code}' -H "Host: $HTTP_HOST" "$@" \
        "$BASE_URL/${REQUEST_PATH#/}")
    printf '\n%s\n' "$REQUEST_PATH"
    perl -ne 'print if m{^HTTP/} or m{^(?:Content-Length|Content-Range|Content-Type|Connection):}i' \
        "$HEADER_FILE"
    wc -c "$BODY_FILE"
}

content_length() {
    perl -ne 'print "$1\n" if m{^Content-Length:\s*(\d+)}i' "$HEADER_FILE"
}

strip_fixture() {
    perl -0777 -pe 's/\n?#[\.,]{70,}\n(?:#[^\n]+\n)+\z//s' "$1"
}

p7c httpd.heart >/dev/null
[[ -r $SMALL_FIXTURE ]] || fail "missing signed fixture : $SMALL_FIXTURE"
[[ -r $LARGE_FIXTURE ]] || fail "missing large signed fixture : $LARGE_FIXTURE"
[[ -w $SITE_DIR ]] || fail "site directory is not writable : $SITE_DIR"

cp -- "$SMALL_FIXTURE" "$SITE_DIR/$SIGNED_NAME"
cp -- "$SMALL_FIXTURE" "$SITE_DIR/$TAMPERED_NAME"
cp -- "$LARGE_FIXTURE" "$SITE_DIR/$LARGE_NAME"
printf '<html><body>unsigned live fixture</body></html>\n' \
    > "$SITE_DIR/$UNSIGNED_NAME"
printf '<!-- tampered -->\n' >> "$SITE_DIR/$TAMPERED_NAME"
chmod 0644 "$SITE_DIR/$SIGNED_NAME" "$SITE_DIR/$UNSIGNED_NAME" \
    "$SITE_DIR/$TAMPERED_NAME" "$SITE_DIR/$LARGE_NAME"

strip_fixture "$SMALL_FIXTURE" > "$TMP_DIR/small.expected"
strip_fixture "$LARGE_FIXTURE" > "$TMP_DIR/large.expected"
SMALL_SIZE=$(wc -c < "$TMP_DIR/small.expected")
LARGE_SIZE=$(wc -c < "$TMP_DIR/large.expected")
UNSIGNED_SIZE=$(wc -c < "$SITE_DIR/$UNSIGNED_NAME")

REQUEST_PATH=/$SIGNED_NAME
request signed
assert_equal 200 "$HTTP_CODE" 'signed file status'
assert_equal "$SMALL_SIZE" "$(content_length)" 'signed Content-Length is stripped size'
cmp -s "$TMP_DIR/small.expected" "$BODY_FILE" \
    || fail 'signed body differs from stripped fixture'
! grep -q 'DATA SIGNATURE' "$BODY_FILE" || fail 'signed body retained its footer'
printf 'ok   : signed body is stripped and exact\n'

REQUEST_PATH=/$SIGNED_NAME
request cached
assert_equal 200 "$HTTP_CODE" 'cached signed file status'
cmp -s "$TMP_DIR/small.expected" "$BODY_FILE" || fail 'cached body changed'
CACHE_LOG=$(p7c httpd.show-buffer zenka 100)
[[ $CACHE_LOG == *"signed-file cache hit : /$SIGNED_NAME : valid : 2"* ]] \
    || fail 'second request was not logged as the second cache hit'
printf 'ok   : second request used the verification cache\n'

REQUEST_PATH=/$SIGNED_NAME
request ranged -H 'Range: bytes=0-4'
assert_equal 206 "$HTTP_CODE" 'signed Range status'
assert_equal 5 "$(content_length)" 'signed Range Content-Length'
dd if="$TMP_DIR/small.expected" of="$TMP_DIR/range.expected" \
    bs=1 count=5 status=none
cmp -s "$TMP_DIR/range.expected" "$BODY_FILE" || fail 'Range used wrong offsets'
perl -ne '$ok = 1 if m{^Content-Range:\s*bytes 0-4/\Q'"$SMALL_SIZE"'\E\r?$}i; END { exit !$ok }' \
    "$HEADER_FILE" || fail 'Content-Range does not use stripped size'
printf 'ok   : Range offsets and total target the stripped body\n'

REQUEST_PATH=/$UNSIGNED_NAME
request unsigned
assert_equal 200 "$HTTP_CODE" 'unsigned file status'
assert_equal "$UNSIGNED_SIZE" "$(content_length)" 'unsigned Content-Length'
cmp -s "$SITE_DIR/$UNSIGNED_NAME" "$BODY_FILE" || fail 'unsigned body changed'
printf 'ok   : unsigned file is unchanged\n'

REQUEST_PATH=/$TAMPERED_NAME
request tampered
assert_equal 403 "$HTTP_CODE" 'tampered signed file is refused'

REQUEST_PATH=/$LARGE_NAME
request large
assert_equal 200 "$HTTP_CODE" 'large signed file status'
assert_equal "$LARGE_SIZE" "$(content_length)" 'large Content-Length is stripped size'
cmp -s "$TMP_DIR/large.expected" "$BODY_FILE" || fail 'large stripped body changed'
! grep -q 'DATA SIGNATURE' "$BODY_FILE" || fail 'large body retained its footer'
printf 'ok   : large real transfer is stripped and exact\n'

REQUEST_PATH=/$LARGE_NAME
printf '\n%s [ client disconnect ]\n' "$REQUEST_PATH"
set +e
DISCONNECT_CODE=$(curl --limit-rate 8192 --max-time 1 -sS \
    -D "$TMP_DIR/disconnect.headers" -o "$TMP_DIR/disconnect.body" \
    -w '%{http_code}' -H "Host: $HTTP_HOST" "$BASE_URL/$LARGE_NAME")
DISCONNECT_RC=$?
set -e
DISCONNECT_SIZE=$(wc -c < "$TMP_DIR/disconnect.body")
perl -ne 'print if m{^HTTP/} or m{^Content-Length:}i' "$TMP_DIR/disconnect.headers"
printf 'curl_rc=%s http_code=%s partial_bytes=%s\n' \
    "$DISCONNECT_RC" "$DISCONNECT_CODE" "$DISCONNECT_SIZE"
[[ $DISCONNECT_RC -ne 0 ]] || fail 'disconnect fixture completed before timeout'
[[ $DISCONNECT_SIZE -gt 0 && $DISCONNECT_SIZE -lt $LARGE_SIZE ]] \
    || fail 'client did not disconnect mid-transfer'

REQUEST_PATH=/$UNSIGNED_NAME
request healthy
assert_equal 200 "$HTTP_CODE" 'server answers after client disconnect'
cmp -s "$SITE_DIR/$UNSIGNED_NAME" "$BODY_FILE" || fail 'post-disconnect body changed'
printf 'ok   : server remains healthy after client disconnect\n'

printf '\n: all live httpd signed-file tests passed\n'

#,,.,,..,,,.,,,,,,,,,,,,.,..,,...,.,.,.,,,.,,,..,,...,...,..,,,..,.,,,,..,...,
#5E65ZTC43I5HVWA4TTOARB3SJL7ZYCXQUVMFBORBTEY4HAIS6BDVK4H32OFIPUKEBB3OYGFUASSC6
#\\\|QKRS3PDA22ZF2IA3D7VPLCTYD6SDE6XBA5CI4DLEA45UQKVKMKP \ / AMOS7 \ YOURUM ::
#\[7]4WOB5VNOG3WGFIYO5AXSTZSDNFUI5NXDHOWTKSDNVLU4RNEGJKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
