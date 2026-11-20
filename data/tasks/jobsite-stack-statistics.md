# jobsite : stack statistics from the postings, and the zenki they suggest

status : brief, not dispatched [ owner 2026-11-20 ]

## idea

the stored postings are a free market survey : which tools are used in practice next to
linux, per category and over time. it answers which skill gaps matter [ weighted by how
many fitting postings name them ] and which management \ monitoring zenki to build first
-- the most named tools are where own tooling also counts as shown experience.

## first sample [ 2026-11-20, plain word count, all statuses ]

939 postings, 154 name linux. within those 154 :

    azure 33 %   windows 30 %   kubernetes 29 %   python 26 %   terraform 21 %
    docker 16 %  ansible 14 %   vmware 9 %        bash 9 %      aws 8 %
    grafana 7 %  gitlab 7 %     go 6 %            openshift 5 % helm 4 %

azure far ahead of aws ; windows next to linux in a third [ mixed environments ] ;
terraform and ansible both strong [ terraform ahead ]. a mention is not a requirement,
and trash \ off-topic postings are counted too -- stage 1 fixes both.

## stages

1. `jobsite.stack-stats [category] [status]` : a term list in p7 config style
   [ tool -> aliases, e.g. `k8s` `kubectl` -> kubernetes ] ; counts per posting
   [ once per posting ], base = postings that name linux, by category and status ;
   requirement vs mention : weight a hit inside the profile \ requirements section higher
   than one in the company intro
2. over time : counts per scan month from fetched_at ; rising \ falling tools ; the
   security share the jobsite zenka already noticed rising is one curve of this
3. co-occurrence : which tools appear together [ kubernetes + helm + gitlab ci ] -- the
   typical stacks per category
4. own gaps : the owner's skills as a list ; per gap the share of fitting postings
   [ score >= threshold ] naming it -> an ordered learning \ tooling list
5. later : the pattern engine proposes new terms it sees often that are not in the list
   [ owner confirms ], instead of a hand-kept list only

## the zenki it suggests

- kubernetes : a zenka reading cluster state through the api [ pods, rollouts, events ]
  and reporting symptoms, not raw alerts [ 'signal not noise' ] ;
  rollout \ rollback watch
- monitoring : grafana \ prometheus as outputs of the existing zenki metrics, not a
  replacement for them
- terraform \ ansible : driving runs and reading their state \ diffs as events
  [ plan -> apply as a two-step, failure-first ]

## rules

- read-only over the job store ; results as a command reply \ report, no new store
- p7 config style for the term list, no json ; internal checksums BMW \ AMOS
- no personal data in repo files : the owner's skill list lives outside the checkout

#,,,,,,.,,,..,..,,.,,,.,.,,,.,,..,.,,,,,,,,,,,..,,...,..,,,.,,..,,,,.,...,.,,,
#WG3SSWHPMGFOIFHEGMWECOMM5BEYUG2HIBVPUEIOFH63DD245OLGQKLEYMI2FX6HWO34ERIFUPXAW
#\\\|USM5K5M5DC35U63ML7MMVLILXY4I5BQ5GC5F3KRWNXQ3O6Q2UBN \ / AMOS7 \ YOURUM ::
#\[7]W6YRXY6PUILXKDE5EKO32FFZPPRS6YIBUS37FUMV74ITO7VA6GBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
