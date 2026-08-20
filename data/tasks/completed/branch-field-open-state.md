# task: branch.field.* — open/closed/field state subroutines

## context

a branch is any region of free continuation capacity. the boundary type
defines the branch and identifies its parent. this task implements the
generic open/closed/field state machinery that all higher branch layers
build on.

design reference: `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md`
design reference: `data/md/design/BRANCH-NAMESPACE-MASTER.md`

## signatures note

do not modify or regenerate AMOS7 signature lines. leave them untouched.

## the three states

```
open    capacity > 0 in at least one axis. continuation possible.
closed  boundary reached in all axes. fingerprint extractable.
field   open in 2+ axes simultaneously. grows until multiple boundaries.
```

a closed branch carries its period fingerprint and parent identifier as
closure metadata. this is not optional — it is the mechanism by which
the parent group is identified without a lookup table.

## data structure

each branch field node lives in the branch data tree:

```perl
<branch.field.$id> = {
    axes     => {
        $axis_name => {
            capacity   => $remaining,
            boundary   => $limit,
            position   => $current,
        },
    },
    state    => 'open',       ## open | closed | field
    parent   => undef,        ## set on close: parent group identifier
    period   => undef,        ## set on close: fingerprint string
    children => [],           ## branch ids opened from this closure
}
```

## modules to create

- `src/branch.field.is_open` — any axis with capacity > 0 → true
- `src/branch.field.boundary` — return boundary value for named axis
  (default axis if only one)
- `src/branch.field.capacity` — remaining capacity = boundary − position
- `src/branch.field.parent_id` — return parent group identifier
  (computed on close; undef if still open)
- `src/branch.field.close` — mark closed, extract period fingerprint
  via `<[branch.calc.fraction.period]>`, store parent
- `src/branch.field.grow` — advance position by delta along named axis;
  return false if boundary would be exceeded; close automatically if
  delta reaches exactly the boundary
- `src/branch.field.axes_open` — list all axes with remaining capacity
- `src/branch.field.axes_boundary` — hashref of boundary per axis
- `src/branch.field.split` — close current branch, register two child
  branches inheriting proportional capacity from parent

## style

- `$ARG` not `$_`, `@ARG` not `@_`
- `<branch.field.$id>->{}` for data tree access
- lowercase comments, `[ word ]` bracket annotations
- `<[base.logs]>->( N, fmt, args )` for logging

## acceptance

- `p7c branch.field.is_open <id>` returns true/false correctly
- growing to boundary auto-closes and sets period fingerprint
- closed branch has non-null parent_id
- split produces two children that sum to parent capacity
- field branches (2+ axes) report all open axes correctly

#,,,,,..,,.,.,..,,,,,,,,,,.,,,,.,,.,.,.,,,..,,..,,...,...,...,,,.,.,.,,,,,,,.,
#7R32WQSUCICVNDSCMPBZNEGXVQV7ZJIW6FFTUVQ5EMFY62BK5CEA2ZWYPEWGHHJBFXQK2UVIOVHEI
#\\\|ZEZZKNWF76XWSCIQXPYIKZU5EYL766TFACVHAH4YKY5TSAFMRNH \ / AMOS7 \ YOURUM ::
#\[7]CUP74LPNWZSS76ANLPF7PSG5GPOG5OKLMU4UYZPW74EMMRV3RYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
