
.: filesystem (mount) agent :.

buffer.system.log_cmd = log.msg

[load_config_file:'defaults']

modules.load        = net io.ip auth fs

access.cmd.usr.core = verify_instance \
                      help ping reload mount unmount remount is_mounted

[load_modules:<modules.load>]
[init_modules]

[net.connect_to_core:'tcp/ip']
[base.get_session_id]

[event.loop]
