## [:< ##

# name  = models.task.cmd
# descr = route name : <task_zenka>.<cmd>
# note  = route name of a task zenka command : '<task_zenka>.<cmd>'
# param = <cmd> [ <task_id> ]
# notes = routes by the task's remembered source zenka [ models.task.
#         zenka-of ] so claims, start, complete and fail always go back
#         to the zenka the task came from. no task id : the first listed
#         task zenka [ models.task.zenki ] -- a single name config routes
#         exactly as before

my $cmd     = shift // '';
my $task_id = shift // '';

my $zenka = <[models.task.zenka-of]>->($task_id);

return sprintf '%s.%s', $zenka, $cmd;

#,,..,,,.,..,,.,.,..,,.,.,,,.,...,,,.,...,,,.,.,.,...,...,.,,,.,,,,..,,..,,.,,
#OXCK5RWRCVSJCQTRKH6O777KTGHZEIG6YPP22DFNWUUXYIXN4AKZ7VHAXJFT57Z467AWWMXJZPK6I
#\\\|T4WUFCOI7XAV327LMDAHJBM7GQ3VEVYVH7UBVGVESGERLNHRH3W \ / AMOS7 \ YOURUM ::
#\[7]XKIL2SOKJPSOEO4UQQWN6FXP6JTZCZJYFHDXIJYBI4S4KFEH6ECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
