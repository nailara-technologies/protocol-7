# task: exact-rational truncated decimal output for calc.val

## relation

improvement to `calc.cmd.val` [ `src/calc.cmd.val` ], the same
module touched by `data/tasks/completed/calc-stdio-multiplex-wiring.md`.
unrelated to the multiplex emitter wiring itself — purely a numeric
formatting change.

## the gap

`calc.val 5/13` currently prints `0.384615384615385` — Perl's default
float stringification, which *rounds* the double to ~15 significant
digits. for repeating-decimal / remainder-sequence work [ e.g. base-13
harmonic analysis ], rounding corrupts the digit sequence: the true
decimal expansion of 5/13 is `0.384615384615384615384615...`
[ repeating block `384615` ], so the correct truncation at 15 fractional
digits is `0.384615384615384`, not `...385`.

for purely rational expressions [ `+ - * /`, integer powers, literal
numbers — no `sin`/`cos`/`sqrt`/variables/etc ], the goal is to compute
the value as an exact `Math::BigRat` and **truncate** [ never round ]
its decimal expansion to a fixed digit count. for anything involving
transcendental functions or variables, fall back to the existing
float `->value` behavior unchanged.

## scope

### `calc.cmd.val.eval_bigrat`

```
# name  = calc.cmd.val.eval_bigrat
# param = $node  [ a Math::Symbolic tree node ]
# descr = recursively evaluate a Math::Symbolic tree as an exact
#         Math::BigRat, if every node is rational-representable;
#         return undef if any node isn't [ caller falls back to
#         $formula->value ]
```

handle these node shapes [ verified against the installed
Math::Symbolic via quick perl one-liners — these are the actual
constants/structure ]:

- `$node->term_type == Math::Symbolic::T_CONSTANT` [ == 1 ]:
  return `Math::BigRat->new( $node->value )`.
- `$node->term_type == Math::Symbolic::T_OPERATOR` [ == 0 ], dispatch
  on `$node->{type}`:
  - `Math::Symbolic::B_SUM` [ 0 ]: sum of recursively-evaluated
    `@{$node->{operands}}` [ return undef if any operand is undef ].
  - `Math::Symbolic::B_DIFFERENCE` [ 1 ]: first operand minus the
    rest, in order.
  - `Math::Symbolic::B_PRODUCT` [ 2 ]: product of all operands.
  - `Math::Symbolic::B_DIVISION` [ 3 ]: left / right [ two operands;
    return undef if right is zero ].
  - `Math::Symbolic::B_NEG` [ 4 ]: negate the single operand.
  - `Math::Symbolic::B_EXP` [ 7 ]: `base ** exponent`, only if the
    evaluated exponent is an integer [ check
    `$exp_bigrat->is_int` or `$exp_bigrat->denominator == 1` ] —
    use `$base_bigrat->copy->bpow($exp_bigrat->numerator)`; return
    undef for non-integer exponents [ falls back to float, e.g.
    `sqrt`-equivalent `^0.5` ].
  - any other operator type [ functions like `sin`, `sqrt`, etc. ,
    or `T_VARIABLE` ]: return undef.

load `Math::BigRat` via `<[base.perlmod.autoload]>->('Math::BigRat')`
[ or `::load`, match whatever `calc.init_code` already uses for
`Math::Symbolic` — check that file for the right autoload/load call ].

### `calc.cmd.val.format_truncated`

```
# name  = calc.cmd.val.format_truncated
# param = $bigrat, $digits
# descr = format a Math::BigRat as a decimal string, truncating [ not
#         rounding ] to $digits fractional digits; trims trailing
#         zero fractional digits [ and the decimal point itself, if
#         the result is a whole number ]
```

implementation sketch [ adjust as needed for correct BigRat/BigInt
method names — verify against the installed Math::BigRat/Math::BigInt
API ]:

```perl
my ( $bigrat, $digits ) = @ARG;

my $sign = $bigrat->is_neg ? '-' : '';
my $abs  = abs($bigrat);

my $num = $abs->numerator;
my $den = $abs->denominator;

my $int_part = $num / $den;          ## [ BigInt division truncates ] ##
my $rem      = $num - $int_part * $den;

my $scale = Math::BigInt->new(10)->bpow($digits);
my $frac  = ( $rem * $scale ) / $den;    ## [ truncating division ] ##

my $frac_str = $frac->bstr;
$frac_str = ( '0' x ( $digits - length($frac_str) ) ) . $frac_str;
$frac_str =~ s|0+$||;

return $frac_str eq ''
    ? "$sign$int_part"
    : "$sign$int_part.$frac_str";
```

### wire into `calc.cmd.val`

after `$value_str = $formula->value;` [ around line 30 ], add a
truncate-digits config read [ `<calc.cfg.truncate_digits> // 15` —
add the `//=` default in `calc.init_code`, same style as
`<calc.log_buffer.name> //= qw| session |` ], then:

```perl
my $bigrat = <[calc.cmd.val.eval_bigrat]>->($formula);
$value_str = <[calc.cmd.val.format_truncated]>->( $bigrat, $digits )
    if defined $bigrat;
```

— placed so the rest of the routine [ `emit_num`, plain-value mode,
`$result_str` formatting, `emit_eout` ] uses this `$value_str`
unchanged. transcendental expressions [ `eval_bigrat` returns undef ]
keep today's float-based `$value_str` exactly as before.

## non-goals

- no change to non-rational [ transcendental / variable ] expression
  handling — float `->value` stays as the fallback.
- no change to the stdio multiplex wiring from the prior task.
- `<calc.cfg.truncate_digits>` default of 15 — no UI/command to change
  it at runtime; a config default is sufficient for this task.

## acceptance criteria

- `calc.val 5/13` → `____ 0.384615384615384 ___ [ 5 / 13 ]`
  [ truncated, last digit `4` not rounded `5` ].
- `calc.val plain 5/13` → `0.384615384615384`.
- `calc.val 2^10` → `____ 1024 ___ [ 2 ^ 10 ]` [ whole number, no
  trailing `.000...` ].
- `calc.val sin(2)` → unchanged float-based output [ fallback path
  still works ].
- `calc.val 2^0.5` → unchanged float-based output [ non-integer
  exponent falls back ].

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`, one-sub-per-file [ no inline `sub {}` helpers ].

#,,,,,,,.,,,.,.,,,..,,.,,,,.,,...,.,.,,,,,,.,,.,.,...,...,,.,,,..,..,,,.,,,,,,
#B6ULNUVI3L7JHT3BLFAMC3INI7KJM4RLAQZ4JZ3ADVF7MPL7GGNC5PHNHACABPND474B3GOF4C7YS
#\\\|XCRC3NEMQFAMGCB5W6FGLC66MGX7LXLNDPAIWWUWXTSN4EO6HCC \ / AMOS7 \ YOURUM ::
#\[7]SPVODUGGH7BTR2UYCCHAXQNQ5P6DIEXCUDPU2NVIPMZZ2PB4Q4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
