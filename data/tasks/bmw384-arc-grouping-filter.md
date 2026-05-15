## [:< ##

# name  = task: implement jobsite assertion-branch BMW384 grouping filter
# descr = compute BMW384 color coordinate for each assertion dimension branch,
#         then group jobs by color proximity for deduplication and auto-archive

## depends on

task: bmw384-color-extract.md — AMOS7::CHKSUM::BMW384 and base.chk-sum.bmw384.*
must be implemented first.

## background

each job in the jobsite zenka has an assertion tree with dimension branches
(location, tech-stack, company-culture, etc.). the reason text of each branch
is a natural semantic fingerprint. hashing that reason text with BMW384 and
extracting the color coordinate gives a routing-geometry-compatible fingerprint
per dimension — jobs with similar reason text in a dimension land near each other
on the color wheel.

## module to create: jobsite.chksum.branch-color

file: modules/jobsite.chksum.branch-color

given a job_id and a dimension name, compute the BMW384 color of that branch:

  1. load job via <[jobsite.job.read]>->($job_id)
  2. extract the reason text:
       $text = $job->{'assertions'}{'dimensions'}{$dimension}{'reason'} // ''
  3. compute raw BMW384 digest:
       use Digest::BMW; my $bmw = Digest::BMW->new(384);
       $bmw->add($text); my $digest = $bmw->digest;
  4. extract color: <[base.chk-sum.bmw384.color]>->($digest)
  5. return { color => $color, arc => $arc_segment, digest => $digest }

## module to create: jobsite.chksum.group-by-branch

file: modules/jobsite.chksum.group-by-branch

given a dimension name, a center job_id, and a radius:

  1. load all jobs via <[jobsite.job.load_all]>
  2. compute center color from center job's branch via jobsite.chksum.branch-color
  3. for each other job, compute its branch color
  4. collect jobs within radius using <[base.chk-sum.bmw384.color-dist]>
  5. return arrayref of { job_id, color, arc, dist } sorted by dist ascending

## module to create: jobsite.cmd.group-jobs

file: modules/jobsite.cmd.group-jobs

command handler: p7c jobsite.group-jobs <dimension> <job_id> [radius]

  - dimension: one of location|tech-stack|company-culture|compensation|
               remote-flexibility|career-growth|team-structure
  - job_id: center job
  - radius: optional, default 500000 (about 3% of wheel)
  - calls jobsite.chksum.group-by-branch
  - returns { mode => 'size', data => formatted table }
    columns: job_id | arc | dist | score | title — company (city)

## auto-archive integration (future, do not implement now)

once grouping works: if two jobs share arc segment in 'location' dimension
and both have location.score < 4, flag the lower-scored one for auto-archive.
note this as a comment in jobsite.chksum.group-by-branch but do not implement.

## style
- $ARG not $_ in loops
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements or pragmas in zenka modules
- autoload Digest::BMW via <[base.perlmod.autoload]>->('Digest::BMW')
- autoload AMOS7::CHKSUM::BMW384 the same way

#,,,,,..,,,..,.,.,,,.,..,,.,.,...,.,.,.,.,,..,..,,...,..,,..,,,,,,,..,,..,..,,
#XXKNRLA7A7K6JYQDC5P6USL7KOFZJHIEF5BWZI4YVT6K5T3XQROAQZEZ6FO2P434YEVIFMTN44F2G
#\\\|Q234QMKUY6WLSWF2U7IC5DBZVQJC5JO5FCY3J3SEYNR2356LPMP \ / AMOS7 \ YOURUM ::
#\[7]LL4JZ6QRO4VLJ34OAYTDWTZQTFSAMH72K4Z7ZPSEFCVWFP6WHYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
