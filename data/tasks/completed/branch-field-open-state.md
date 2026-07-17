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

- `modules/branch.field.is_open` — any axis with capacity > 0 → true
- `modules/branch.field.boundary` — return boundary value for named axis
  (default axis if only one)
- `modules/branch.field.capacity` — remaining capacity = boundary − position
- `modules/branch.field.parent_id` — return parent group identifier
  (computed on close; undef if still open)
- `modules/branch.field.close` — mark closed, extract period fingerprint
  via `<[branch.calc.fraction.period]>`, store parent
- `modules/branch.field.grow` — advance position by delta along named axis;
  return false if boundary would be exceeded; close automatically if
  delta reaches exactly the boundary
- `modules/branch.field.axes_open` — list all axes with remaining capacity
- `modules/branch.field.axes_boundary` — hashref of boundary per axis
- `modules/branch.field.split` — close current branch, register two child
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

#,,,,,,,,,.,.,.,.,,.,,,,,,.,.,.,,,...,.,,,,,,,..,,...,...,.,.,,.,,,..,,..,,.,,
#6G2JHDJNYZIGTY6PPTDB3SZVP4U4U33DH3SDNWY6XR7G2NMZM46T3URTFXJ422TUX5HT2QYIJ2OY2
#\\\|4QZ4P4N7GBECYEUA2KMXU6FLDMSU7DFS56FK75N2YX5OA6K6GCI \ / AMOS7 \ YOURUM ::
#\[7]HGAWYRITLNGGHLTGE6MW25PILAIX2WFPFQLUNZV37JTJVNHMTQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
