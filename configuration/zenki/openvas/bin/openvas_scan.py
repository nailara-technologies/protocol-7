#!/usr/bin/env python3
## [:< ##
#
# name  = openvas_scan.py
# descr = thin gvm-tools scan driver for the 'openvas' zenka
#
# control path : GMP over gvmd unix socket via the 'gvm' python library
# [ gvm-tools ]. backend : greenbone community containers [ docker ].
# see modules/openvas.cmd.scan-run header for the full backend decision notes.
#
# emits a single json document on stdout :
#   { status, scan_id, report_id, target, findings : [ { oid, severity,
#     name, target } .., ] }
# on any failure : { status : 'error', error : '<summary>' } + exit 1
# never fabricates findings -- an unreachable backend is an error, not
# an empty result set.

import argparse
import json
import sys
import time


def fail(msg):
    print(json.dumps({'status': 'error', 'error': str(msg)}))
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='openvas zenka scan driver')
    parser.add_argument('--socket', required=True, help='gvmd unix socket')
    parser.add_argument('--user', default='admin')
    parser.add_argument('--password', default='admin')
    parser.add_argument('--target', required=True)
    parser.add_argument('--ports', default='')   ## e.g. 'T:1-1024,8080'
    parser.add_argument('--scan-config', required=True,
                        help='greenbone scan config name [ profile ]')
    parser.add_argument('--poll', type=int, default=15)
    parser.add_argument('--timeout', type=int, default=14400)
    args = parser.parse_args()

    try:
        from gvm.connections import UnixSocketConnection
        from gvm.protocols.gmp import Gmp
    except ImportError:
        fail('gvm-tools not installed [ pip install gvm-tools ]')

    try:
        connection = UnixSocketConnection(path=args.socket, timeout=60)
        gmp_ctx = Gmp(connection)
        gmp = gmp_ctx.__enter__()
    except Exception as exc:
        fail('cannot connect to gvmd socket %s [ backend container down? ]'
             ' : %s' % (args.socket, exc))

    try:
        gmp.authenticate(args.user, args.password)

        ## resolve scan config [ profile ] by name ##
        configs = gmp.get_scan_configs(
            filter_string='name="%s"' % args.scan_config)
        config_ids = [c.get('id') for c in
                      configs.findall('.//config') if c.get('id')]
        if not config_ids:
            fail('scan config not found : %s' % args.scan_config)
        config_id = config_ids[0]

        ## create target ##
        target_kwargs = {'name': 'p7-openvas-%d' % int(time.time()),
                         'hosts': [args.target]}
        if args.ports:
            target_kwargs['port_range'] = args.ports
        target_id = gmp.create_target(**target_kwargs).get('id')

        ## create + start task ##
        task_id = gmp.create_task(
            name='p7-scan-%d' % int(time.time()),
            config_id=config_id, target_id=target_id,
            scanner_id=None).get('id')
        gmp.start_task(task_id)

        ## poll until terminal status ##
        deadline = time.time() + args.timeout
        status = ''
        while time.time() < deadline:
            task = gmp.get_task(task_id).find('.//task')
            status = task.findtext('status') or ''
            if status in ('Done', 'Stopped', 'Interrupted'):
                break
            time.sleep(args.poll)
        else:
            gmp.stop_task(task_id)
            fail('scan timeout after %ds' % args.timeout)

        report_id = task.find('.//last_report/report').get('id')

        ## extract findings ##
        findings = []
        results = gmp.get_results(
            filter_string='report_id=%s' % report_id)
        for res in results.findall('.//result'):
            nvt = res.find('.//nvt')
            findings.append({
                'oid':      nvt.get('oid') if nvt is not None else '',
                'severity': float(res.findtext('severity') or 0),
                'name':     nvt.findtext('name') if nvt is not None else '',
                'target':   res.findtext('host') or args.target,
            })

        ## clean up scan artifacts [ keep gvmd lean ] ##
        try:
            gmp.delete_task(task_id, ultimate=True)
            gmp.delete_target(target_id, ultimate=True)
        except Exception:
            pass

        print(json.dumps({
            'status':    status,
            'scan_id':   task_id,
            'report_id': report_id,
            'target':    args.target,
            'findings':  findings,
        }))
    except SystemExit:
        raise
    except Exception as exc:
        fail(str(exc))
    finally:
        try:
            gmp_ctx.__exit__(None, None, None)
        except Exception:
            pass


if __name__ == '__main__':
    main()

#,,,,,,,,,.,,,.,,,,,,,,,.,,,,,,..,.,.,,,,,.,.,.,.,...,...,,,,,,,.,,..,.,.,,,,,
#XC6IOQ7TCU7DHGRCRAWMSPQOORXS4V3UGYIGEYFCPSGYVTJW4DHFRVEDSPLVC2U3UX5IAXZLTZXMC
#\\\|H6MKF2OYKHXTY2SZWGVJB6IACE7A2HS4R4VAKGAYZFNM3BTTEXZ \ / AMOS7 \ YOURUM ::
#\[7]WHXO5UOF32MEGPCJ4H6EWW3KWOQLZG4DEERKHIH7F2DAEZRBMKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
