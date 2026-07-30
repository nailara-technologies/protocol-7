#!/usr/bin/env python3
## [:< ##
#
# name  = nessus_scan.py
# descr = thin nessus REST API scan driver for the 'nessus' zenka
#
# control path : nessus professional REST API [ nessusd on
# https://127.0.0.1:8834/, self-signed cert -> verification disabled,
# localhost only ]. auth : POST /session with username+password ->
# session token [ X-Cookie ]. the trial license allows exactly ONE
# user, so no dedicated service account is possible -- the shared UI
# user's credentials are used [ see nessus.cfg.username/password ].
# API keys [ X-ApiKeys ] are the alternative once generated in the UI.
#
# emits a single json document on stdout :
#   { status, scan_id, report_id, target, findings : [ { oid, severity,
#     name, target } .., ] }
# on any failure : { status : 'error', error : '<summary>' } + exit 1
# never fabricates findings -- an unreachable backend is an error, not
# an empty result set.
#
# findings shape matches the openvas backend exactly [ same keys ] :
#   oid      = 'nessus-plugin-<id>'   [ nessus plugin id namespace is
#             kept distinct from nvt oids on purpose -- see
#             data/tasks/nessus-agent.md notes ]
#   severity = float on the openvas-compatible 0..10 cvss scale, mapped
#             from the nessus 0..4 ordinal : 0->0.0, 1->2.0, 2->5.0,
#             3->7.5, 4->10.0 [ ordinal-band midpoint approximation ]
#   name     = plugin name .., target = scanned host

import argparse
import json
import ssl
import sys
import time
import urllib.request
import urllib.error

SEVERITY_MAP = {0: 0.0, 1: 2.0, 2: 5.0, 3: 7.5, 4: 10.0}


def fail(msg):
    print(json.dumps({'status': 'error', 'error': str(msg)}))
    sys.exit(1)


class NessusClient:
    def __init__(self, base_url, timeout=60):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.token = None
        ## self-signed cert on localhost : no verification ##
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        ## ProxyHandler({}) : bypass env proxies for localhost ##
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}),
            urllib.request.HTTPSHandler(context=ctx))

    def request(self, method, path, payload=None):
        url = self.base_url + path
        headers = {'Content-Type': 'application/json'}
        if self.token:
            headers['X-Cookie'] = 'token=%s' % self.token
        data = json.dumps(payload).encode() if payload is not None else None
        req = urllib.request.Request(url, data=data,
                                     headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=self.timeout) as resp:
                body = resp.read().decode() or '{}'
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors='replace')[:300]
            ## 412 'API is not available' == trial license scan_api:false ##
            fail('http %d on %s %s : %s' % (
                exc.code, method, path, body))
        except urllib.error.URLError as exc:
            fail('cannot reach nessus at %s [ nessusd down? ] : %s' % (
                self.base_url, exc.reason))
        except OSError as exc:
            ## transient socket failures [ reset during server state      ##
            ## transitions ] reported as clean errors, not tracebacks     ##
            fail('connection error on %s %s : %s' % (method, path, exc))

    def login(self, username, password):
        reply = self.request('POST', '/session',
                             {'username': username, 'password': password})
        self.token = reply.get('token')
        if not self.token:
            fail('no session token in /session reply [ bad credentials? ]')

    def logout(self):
        try:
            self.request('DELETE', '/session')
        except SystemExit:
            pass


def main():
    parser = argparse.ArgumentParser(description='nessus zenka scan driver')
    parser.add_argument('--base-url', required=True)
    parser.add_argument('--username', required=True)
    parser.add_argument('--password', required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--ports', default='')   ## e.g. '1-1024,8080'
    parser.add_argument('--scan-template', required=True,
                        help='nessus scan template title [ profile ]')
    parser.add_argument('--poll', type=int, default=15)
    parser.add_argument('--timeout', type=int, default=14400)
    args = parser.parse_args()

    client = NessusClient(args.base_url)
    client.login(args.username, args.password)

    scan_id = None
    try:
        ## resolve scan template [ profile ] by title ##
        templates = client.request('GET', '/editor/scan/templates')
        template_uuid = None
        available = []
        for tpl in templates.get('templates', []):
            available.append(tpl.get('title', ''))
            if tpl.get('title') == args.scan_template:
                template_uuid = tpl.get('uuid')
        if not template_uuid:
            fail('scan template not found : %s [ available : %s ]' % (
                args.scan_template, ', '.join(sorted(available))))

        ## create scan ##
        settings = {
            'name': 'p7-nessus-%d' % int(time.time()),
            'text_targets': args.target,
            'launch': 'ON_DEMAND',
            'enabled': False,
        }
        if args.ports:
            settings['portscan_range'] = args.ports
        scan = client.request('POST', '/scans',
                              {'uuid': template_uuid,
                               'settings': settings})
        scan_id = scan.get('scan', {}).get('id')
        if not scan_id:
            fail('no scan id in POST /scans reply')

        ## launch ##
        launched = client.request('POST', '/scans/%d/launch' % scan_id)
        scan_uuid = launched.get('scan_uuid', '')

        ## poll until terminal status ##
        deadline = time.time() + args.timeout
        status = ''
        terminal = ('completed', 'stopped', 'canceled', 'aborted')
        while time.time() < deadline:
            info = client.request('GET', '/scans/%d' % scan_id)
            status = info.get('info', {}).get('status', '')
            if status in terminal:
                break
            time.sleep(args.poll)
        else:
            try:
                client.request('POST', '/scans/%d/stop' % scan_id)
            except SystemExit:
                pass
            fail('scan timeout after %ds' % args.timeout)

        ## extract findings [ per-host detail ] ##
        findings = []
        scan_doc = client.request('GET', '/scans/%d' % scan_id)
        hosts = scan_doc.get('hosts', [])
        for host in hosts:
            host_id = host.get('host_id')
            hostname = host.get('hostname') or args.target
            detail = client.request(
                'GET', '/scans/%d/hosts/%d' % (scan_id, host_id))
            for vuln in detail.get('vulnerabilities', []):
                sev_int = int(vuln.get('severity', 0))
                findings.append({
                    'oid': 'nessus-plugin-%s' % vuln.get('plugin_id', ''),
                    'severity': SEVERITY_MAP.get(sev_int, 0.0),
                    'name': vuln.get('plugin_name', ''),
                    'target': hostname,
                })

        ## clean up scan artifacts [ keep nessusd lean ] ##
        try:
            client.request('DELETE', '/scans/%d' % scan_id)
        except SystemExit:
            pass

        print(json.dumps({
            'status':    status,
            'scan_id':   str(scan_id),
            'report_id': scan_uuid,
            'target':    args.target,
            'findings':  findings,
        }))
    finally:
        client.logout()


if __name__ == '__main__':
    main()

#,,,,,,,,,.,,,.,,,,,,,,,.,,,,,,..,.,.,,,,.,.,.,...,...,,,,,,,.,,..,.,,,.,,,,,
#XC6IOQ7TCU7DHGRCRAWMSPQOORXS4V3UGYIGEYFCPSGYVTJW4DHFRVEDSPLVC2U3UX5IAXZLTZXMC
#\\\|H6MKF2OYKHXTY2SZWGVJB6IACE7A2HS4R4VAKGAYZFNM3BTTEXZ \ / AMOS7 \ YOURUM ::
#\[7]WHXO5UOF32MEGPCJ4H6EWW3KWOQLZG4DEERKHIH7F2DAEZRBMKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
