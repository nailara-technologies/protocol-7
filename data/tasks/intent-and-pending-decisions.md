# intent and pending decisions : sign the what, let the best how complete it

status : brief, not dispatched [ owner 2026-11-21 ]. builds on
data/tasks/httpd-signed-files.md [ delegation chain over the zenka network ],
token-lease-and-lan-media.md [ groups, scopes, leases ], work-and-private-contexts.md
[ contexts, provenance ], the protocol-7-menu pending questions
[ pending-question-add \ open \ answer ], data/md/design/RESOURCE-ACCOUNTING-UNIFIED.md
and NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md [ NRT \ NRD, ledger, shares ].

## principle : the user records intent, not method

- the user signs an intent : what should happen, not how [ 'keep these documents with
  three copies', 'publish this page', 'have this report by morning' ]
- the intent bounds the method : scope [ which data ], effect [ read, write, publish,
  delete ], maximum level, time window, resource budget
- inside those bounds the currently best or matching method is pre-authorised to
  complete it -- which holder, transport, key, generator, model. a better method
  later needs no new approval, the intent is unchanged
- the trust chain makes this hold at any distance : every executor is reached through
  signed delegations over the zenka network ; revocation travels the same channel
- every execution is recorded as 'intent x, carried out by method y' -- the user can
  see what was done in their name, and how

## pending decisions : open questions as blocking dependencies

- a step that needs a decision outside the intent's bounds becomes a pending question
  [ protocol-7-menu ] -- it does not guess and does not abort
- it blocks only the steps that depend on it ; independent work continues
- it waits where the user will see it [ presence, see input-and-window-forwarding.md ],
  answered at once or later ; the answer is itself a small signed intent, recorded with
  the original

## escalation before a consequence

some questions carry a consequence time [ a certificate expiring, a disk filling, a
delivery ] -- there, any decision is better than none. per question, optional :

1. a quiet notice where the user is
2. louder and wider [ other hosts, the phone, an alarm ]
3. a delegated person chosen beforehand for this kind of decision
4. shortly before the deadline : the pre-chosen default

the default is chosen by asymmetry : the safe automatic decision almost always costs
RESOURCES, not data or operation [ renew instead of letting a service lapse, one more
copy instead of risking the only one, keep longer instead of deleting early, pause
instead of continuing wrongly ] -- disk, power or bandwidth are cheap and recoverable,
lost data and a stopped operation are often not. each step is recorded as 'decided
because of the deadline', reversible where the default allows

## budgets from the resource pools

- an intent may carry a budget drawn from the resource pools [ NRT \ NRD ledger,
  RESOURCE-ACCOUNTING-UNIFIED.md : shares, slots, the `ltok` unit for llm tokens ]
- example : an external llm token budget for work that leaks nothing [ the input
  classified generic, no private context, no personal data -- the work and private
  contexts decide ] but that local models cannot finish in time. local first ; the
  external budget is used only when the deadline needs it and the data class allows it
- spending is recorded against the intent like every other step ; an exhausted budget
  becomes a pending question, never a silent overrun

## external assertion sources : trusted for the decision, nothing else

- an outside source [ an external model, a service, another person's zenki ] may be
  trusted to DECIDE a pending question -- its answer is an assertion, taken as the
  decision for exactly that question
- the trust stops there : the answer carries no capability. it cannot trigger
  activity in another context, start other intents, widen a scope or reach data the
  question did not name. whatever it 'asks for' beyond the decision is ignored or
  becomes a new pending question for the user
- the question sent out holds only what the decision needs [ the generic, non-leaking
  part ] ; the reply is checked against the allowed answers of that question
  [ a choice from a list, a value in a range ], free text never becomes an action
- recorded like every step : which source decided which question, with which answer
- context on demand, not dumped up front : instead of handing the source all context
  at the start, the question carries a lookup access map -- named entries the source
  may ask for [ 'the deadline', 'the size of the tree', 'the last error text' ], each
  with its own data class and leak check. the source requests only what it needs,
  each lookup is answered or refused on its own and recorded ; the map itself is the
  index of what was available and the log of what was actually read
- the system may still point at what the source might want to know : a hint that
  NAMES an entry [ 'see: last_error -- changed since the question was asked' ]
  without its content. the source decides whether to look it up, through the same
  checked lookup -- awareness without disclosure

## stages

1. intent records : signed, bounded [ scope, effect, level, window, budget ], with the
   execution log 'intent -> method'
2. pending questions tied to intents [ protocol-7-menu ], blocking only dependants
3. consequence times and the escalation ladder ; defaults by asymmetry
4. budgets from the resource ledger ; the external llm budget with the leak check
5. method selection : the best available executor inside the bounds, re-chosen when a
   better one appears

## rules

- fail closed : an action outside every signed intent does not run
- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- timers through <[base.interval.next]>
- no host names or personal data in repo files

#,,.,,,..,,..,.,.,.,.,.,.,..,,..,,.,,,,,,,..,,..,,...,...,,..,,.,,,..,,.,,.,,,
#GT43XWONT36JRL6CNKOYXU627WZBIOSHD55BIPLFMZEN7VTLAZZHVEUNSQNU5SMAV7S3UJ3TCYS2Q
#\\\|ZZIGS2LBNR3TLIQVWCQOA45OZKFAXSYDEWUWZPYJC36I44V6LDF \ / AMOS7 \ YOURUM ::
#\[7]C7KWEUIEZJRUBJL7JTZEJ5RWM34PTA47HD5HK2FGV5U4JGQQEEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
