
.: filesystem (mount) agent :.

buffer.system.log_cmd = log.msg

[load_config_file:'defaults']

modules.load        = net io.ip auth fs

access.cmd.usr.core = verify_instance \
                      help ping reload mount unmount remount is_mounted

[load_modules:<modules.load>]
[init_modules]

core.handle = [base.open:'tcp/ip','out',<net.local.addr>,<net.local.port>]
core.handle = [auth.agent.client:<core.handle>,<system.agent.name>]
[base.session.init:<core.handle>,'nailara','client','core']
[base.get_session_id]

[event.loop]
