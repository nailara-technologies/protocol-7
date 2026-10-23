## [:< ##

# name  = models.task.cmd
# descr = route name : <task_zenka>.<cmd>
# note  = route name of a task zenka command : '<task_zenka>.<cmd>'
# param = <cmd>
# notes = <models.cfg.task_zenka> //= 'task' [ the local task zenka ] ; an
#         external route like 'external.<link>.task' makes this host claim
#         another host's tasks [ see models.task.remote ]

my $cmd = shift // '';

my $task_zenka = <models.cfg.task_zenka> // qw| task |;
$task_zenka =~ s{^\s+|\s+$}{}g;
$task_zenka = qw| task | if not length $task_zenka;

return sprintf '%s.%s', $task_zenka, $cmd;

#,,.,,.,.,,.,,.,.,,..,..,,.,.,...,...,,..,...,..,,...,...,...,.,,,.,,,...,,,,,
#CZ56GS72FQVNSRGLSEPKGYKLC6O7J334OQ2LWNTBVJA2AAMXDL6IRLC5UOIPIR4SD5XVACPAWEXCW
#\\\|AXHJWIKSL3757YWWLXVCMQ4IIIJMGVCKSRWANGOTWEJO7BTV23U \ / AMOS7 \ YOURUM ::
#\[7]LY2JDCOOEDAA74YLZHGT65DZGOAGHDEMMVY7JYMKFBPKQNJJKEAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
