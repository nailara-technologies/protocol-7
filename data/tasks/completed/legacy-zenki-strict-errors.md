# legacy zenki : errors found by the strict format-code check

## found [ 2026-09-30 ]

`bin/format-code -c` compiles P7 modules under `use strict` with the loader's
imports since fbbc58194. a run over all of src/ left these errors -- all in
zenki no running zenka loads, so no compile report ever showed them. each
module would fail at the zenka's source update [ or, without strict, run with
undef \ empty values ].

## files

- `src/ssl.list_ssl` : Global symbol '$output' requires explicit package name (did you forget to declare 'my $output'?). [src/ssl.list_ssl:6]; Global symbol '$output' requires explicit package nam
- `src/ssl.cmd.add_ssl` : Global symbol '$id' requires explicit package name (did you forget to declare 'my $id'?).; Global symbol '$com_id' requires explicit package name (did you forget to decla
- `src/power.set_states` : Bareword 'SOCK_ON' not allowed while 'strict subs' in use.; Bareword 'SOCK_OFF' not allowed while 'strict subs' in use. [src/power.set_states:15]; Bareword 'SOCK_SKIP' not allowed while 'strict subs' 
- `src/ssl.cmd.read_data` : Global symbol '$id' requires explicit package name (did you forget to declare 'my $id'?).; Global symbol '$com_id' requires explicit package name (did you forget to declare 'my $com_id'?).; Global sym
- `src/download.init_code` : Use of uninitialized value in integer addition (+).; Use of uninitialized value in integer addition (+). [src/download.init_code:52]
- `src/ssl.connect_handler` : Global symbol '$new_sock' requires explicit package name (did you forget to declare 'my $new_sock'?). [src/ssl.connect_handler:6]; Global symbol '$new_sock' requires explicit package name (did you for
- `src/power.cmd.set_states` : Bareword 'SOCK_ON' not allowed while 'strict subs' in use.; Bareword 'SOCK_OFF' not allowed while 'strict subs' in use. [src/power.cmd.set_states:47]; Bareword 'SOCK_SKIP' not allowed while 'strict su
- `src/power.cmd.get_states` : Bareword 'SOCK_SKIP' not allowed while 'strict subs' in use.; Bareword 'SOCK_SKIP' not allowed while 'strict subs' in use.; Bareword 'SOCK_SKIP' not allowed while 'strict subs' in use.; Bareword 'SOCK
- `src/download.util.resolve` : Global symbol '@ARG' requires explicit package name (did you forget to declare 'my @ARG'?). [src/download.util.resolve:10]
- `src/ticker.load_font_offsets_table` : if'
- `src/keys.select_archive_path.term_Clui` : Global symbol '$file' requires explicit package name (did you forget to declare 'my $file'?). [src/keys.select_archive_path.term_Clui:56]; Global symbol '$file' requires explicit package name (did you
- `src/weather.widget.util.get_weather_widget_css` : Global symbol '@keyframes' requires explicit package name (did you forget to declare 'my @keyframes'?). [src/weather.widget.util.get_weather_widget_css:23]; Global symbol '@keyframes' requires explici

## notes

- `ssl.*` : `local $output` on an undeclared package variable, undeclared
  `$id` \ `$com_id` \ `$new_sock` -- last touched in the 2026-08 src/ rename
- `power.*` : `SOCK_ON` \ `SOCK_OFF` \ `SOCK_SKIP` are defined nowhere in src/
- `weather.widget.util.get_weather_widget_css` : `@keyframes` inside `qq|..|`
  interpolates as an array -- the css animations would vanish ; escape `\@`
- `download.util.resolve` : `@ARG` after `package Download::UserAgent;` --
  English aliases @ARG in main only ; use `@_` there
- `download.init_code` : only a compile-time warning [ uninitialized value in
  integer addition ]
- `ticker.load_font_offsets_table` : message truncated in the report, look
  at `bin/format-code -c src/ticker.load_font_offsets_table` directly

## how to verify

`bin/format-code -c <file>` must report `syntax valid` for each ; do not
reload \ start these zenki as part of the fix unless the user asks.

#,,.,,,,.,,,.,,,.,.,.,,..,.,.,,,,,..,,..,,,,,,..,,...,...,..,,,..,,..,.,,,,.,,
#ZIMQ5NL5QCKC27U5RCORHO3ZFH474ATRMBY4TRLGQLAWS3J7WFEJWHG27ELODJBA3D7ND2AHDVH4E
#\\\|E5BDEBVSOJKA5EQFWHTHZP2GJOLXYZZSQFQ4V5KNN7RLPYZB53D \ / AMOS7 \ YOURUM ::
#\[7]M5AUSW5JLKNAYN6DYDRFLS3HWB2V5XUDBBTV5EBOI3JY32XQXSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
