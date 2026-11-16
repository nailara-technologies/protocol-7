# decision guide [ 2026-11-16 ]

the open owner questions of `RESOURCE-ACCOUNTING-UNIFIED.md` [ ledger ],
`SUBSTRATE-SYNTHESIS.md` [ synthesis ] and `N7FS-FORMAT-4.md` [ format 4 ],
ordered by what they block for building. each has a recommendation ; a
plain "yes" to it is enough. nothing here is new design.

## 1. the questions, most blocking first

**blocks format 4 stage 1 [ the shared canon parser ] and ledger stage 1a**

1. **format 4, question 2 : where does the shared parser live ?**
   - recommend : `AMOS7::cell::canon` with `AMOS7::cell::canon::list`
     [ both harmony TRUE, a hint only ]
   - reason : neither user owns it, so the ledger never loads n7fs code and
     n7fs never loads the ledger
   - unblocks : format 4 stage 1, and with it ledger stage 1a

2. **format 4, question 4 : keys written `root-id` or `root_id` ?**
   - recommend : `root-id`
   - reason : the ledger already writes its keys this way, and one form
     should have one key pattern
   - unblocks : the key pattern of stage 1, every kind table of stage 2

3. **format 4, question 7 : how is free text written ?**
   - recommend : bare when printable ASCII and base32 otherwise in heads,
     always base32 in rows
   - reason : readable where a person looks, one spelling and no test on
     the hot path
   - unblocks : the strictness cases of stage 1

4. **format 4, question 13 : text everywhere, no binary record form ?**
   - recommend : yes
   - reason : a binary shard gains 0.01 s on the whole map and costs the
     shared parser
   - unblocks : the scope of stage 1 [ one body reader, not two ]

**blocks ledger stage 1a**

5. **ledger, question 34 : one key signs for one giver, several givers go
   through a slot ?**
   - recommend : yes
   - reason : the canon form carries one signature, and a slot is already
     "a transaction is itself a small pool"
   - unblocks : the `transaction` kind table and check 27

6. **ledger, question 24 : is 9 999 999 999 999 drops per domain the meaning
   of "13 digit numbers", also for the network account ?**
   - recommend : yes
   - reason : one bound for every balance makes supply bounded and every sum
     checkable
   - unblocks : check 3 of stage 1a

7. **ledger, question 32 : `recover` appends a `void` record, and `void` is
   the word ?**
   - recommend : yes to both
   - reason : no record ever leaves the journal, and the word is written
     into journals, so it should be final before the first one
   - unblocks : the journal rules of 1a, check 17 of 1b

**blocks ledger stage 1b**

8. **ledger, question 4 : frame level Y3 or Y4, and is the dissemination
   cycle one frame ?**
   - recommend : Y3, and one frame per cycle
   - reason : long enough for proofs to arrive ; Y4 multiplies the journal
     by 13
   - unblocks : the `init` record default, share budgets and `settle`

9. **synthesis, question 4 : must every pool name an accounting parent ?**
   - recommend : no, a pool may stand with none
   - reason : an ownerless slot [ the pizza ] must be openable by anybody
     without asking a wider pool first
   - unblocks : pool addresses of stage 1b

**blocks format 4 stage 2 and later**

10. **format 4, question 6 : keep the format 1 id record frozen ?**
    - recommend : yes, read by one fixed pattern
    - reason : a new disk identity unbinds every seal-root binding, every
      map `disks` field and every sync origin
    - unblocks : stage 2 [ the id reader ], both upgrade paths

11. **format 4, question 18 : which upgrade path does the live store take ?**
    - recommend : path B [ in place ], decided only after stage 6 passed
      for both paths
    - reason : it avoids the address map through four holders, the one
      coupling that has never run
    - unblocks : the runbook of stage 7 ; no stage before it

12. **synthesis, question 2 : BMW for identity edges, the AMOS 7 only as
    route prefix ?**
    - recommend : yes, BMW L13 for tree edges, 384 where it signs or pays
    - reason : the AMOS 7 is 32 bits, two of about 77 000 entries share one
      with a chance of one half
    - unblocks : any stored tree address, the namespace tree

## 2. proposed answers that only need a "yes"

- ledger 7 : idle readiness is paid from a pool's burst margin, never by an
  issue
- ledger 17 : storage slots are served from the core part first ; an
  uncovered holder keeps bytes one receipt age [ 3Y2 ]
- ledger 18 : a reservation lives one cycle ; a saturated, unproven slot
  holds its drops one check interval, then returns them
- ledger 20 : nobody closes an ownerless pool ; unused, its capacity falls
  toward zero and it overflows back
- ledger 5 : cold balances only slow down, they never shrink
- ledger 10 : a storage span is paid only between two `full` receipts
- ledger 11 : outside llm providers are report-only `ext`, never drops
- ledger 14 : a provider does not see who filled a slot, unless the slot
  uses traced returns
- ledger 26 : a converting zenka is paid on proof of the order, never at
  saturation
- ledger 28 : capacity is measured from earlier cycles, a new pool starts
  small
- ledger 30 : public pool drops do not fund outside purchases
- ledger 33 : a ledger whose old proof bytes are gone is still whole, and
  `verify -proofs` says so per proof
- format 4, 19 : on path B the disk accepts no change between the switch
  and `confirm`
- format 4, 20 : `-grid exact` right after the roll-out ; new disks exact
  from the first day
- format 4, 21 : `epoch-num` under the exact rule is the exact quotient cut
  to 13 digits

## 3. what can wait

everything else waits for its own stage : ledger 2, 3, 6, 8, 9, 12, 21, 25,
27, 29 [ issuance, weights, depth, keys, bridge, loves_it : stage 3 and
later ] ; synthesis 3, 5 to 11, 15 [ none needed for the two ready steps ] ;
format 4, 8 to 12, 14 to 16, 22 [ decided at stage 3 or at the roll-out ].

#,,,.,,,.,,..,.,.,.,.,..,,,.,,,,.,,,,,.,,,..,,..,,...,...,..,,,..,,,,,..,,,..,
#MEAX5LW5ZVEKL7ZVRWXWMLDEGKGO2BVSBNHJPCVUJAL73ASV3IWNHSHUFICTMVWCLTX6W6CLVTR3C
#\\\|KEVDXL4YKK3MOJLIKIVXNRWHSTH3FMPKNA37WLZY2G7ENX7AR45 \ / AMOS7 \ YOURUM ::
#\[7]ZFNQT2B4HZETBUKR46UXOOBR4O7ZJW5OO6DT6ERZABRBYVTGD2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
