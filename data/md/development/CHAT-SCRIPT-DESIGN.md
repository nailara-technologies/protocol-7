
    .: bin/chat — multi-model conversation script :.


##[ overview ]################################################################

    bin/chat is a lightweight, file-backed multi-model conversation script.
    it supports the user, kimi, claude, and local inference models as equal
    participants. chat history is stored in data/chat/ and committed with the
    repository, making sessions persistent across nodes and resumable at any
    time.

    design goals :

        - clean parity between user and model as participants
        - channels as the primary organizing axis ( not models )
        - automatic caller detection for session separation
        - same -wait-reply / -file interface as coding-task and kimi-task
        - xz archive on clear — nothing is ever permanently lost
        - foundation for consensus testing without requiring zenki infra


##[ directory layout ]########################################################

    data/chat/
      channel/
        main/                    ← ambient parent channel [ always present ]
          history                ← active chat log ( plain text, committed )
          context/               ← per-model rolling context snapshots
            kimi-code.ctx
            claude-code.ctx
            <amos-id>.ctx
        job-site-scan/           ← task-focused sub-channel
          history
          context/
        chat-script/
          history
          context/
        ...
      archive/
        channel/
          main/
            2026-05-14T15:32:11.xz
            2026-05-14T09:11:44.xz
          job-site-scan/
            2026-05-14T18:00:00.xz
      model/
        kimi-code/               ← persistent cross-channel model memory
          memory
        claude-code/
          memory
        <amos-id>/
          memory


##[ channel selection ]#######################################################

    channels are selected with the # sigil as a keyword :

        :#main:            switch to main channel       [ default ]
        :#job-site-scan:   switch to job-site-scan channel
        :#new-topic:       create and switch to a new channel

    the active channel persists until explicitly switched.
    sub-channels use slash notation in the keyword : :#main/social:

    channels map directly onto directory names under data/chat/channel/.
    creating a channel is just switching to one that does not yet exist.


##[ model selection ]#########################################################

    models are selected with the : sigil :

        :kimi:             kimi-code via kimi zenka
        :claude:           claude via MCP / API
        :all:              broadcast to all active models [ consensus mode ]
        :<amos-id>:        local inference model by AMOS id

    the active model persists until switched. the script infers from the
    keyword whether it is a channel switch or a model switch — # for channel,
    bare word for model.

    :all: collects responses from each model and presents them side by side.
    this is the entry point for consensus testing without zenki infrastructure.


##[ caller detection ]########################################################

    the script detects its caller to maintain separate session identities :

        P7_CHAT_CALLER=kimi-code     set explicitly by calling shell
        P7_CHAT_CALLER=claude-code   set by claude coding environment
        P7_CHAT_CALLER=user          default when called interactively

    fallback : inspect parent process name via /proc/<ppid>/comm.
    the caller identity is recorded in each history entry so the log shows
    who said what, including when a model is replying to another model.

    history entry format :

        [2026-05-14T15:32:11] <user>        hello, how is it going?
        [2026-05-14T15:32:14] <kimi-code>   doing well — working on fetch queue
        [2026-05-14T15:32:19] <claude-code> same here, reviewing the design doc


##[ command line interface ]##################################################

    .: bin/chat usage :.

    bin/chat [options] [message]

    -w  .......  wait for reply before exiting [ --wait-reply ]
    -f  .......  read message from file        [ --file <path> ]
    -c  .......  specify channel               [ --channel <name> ]
    -m  .......  specify model                 [ --model <id> ]
    -q  .......  quiet — no decorative output

    -clear  ...  archive current channel and start fresh
    -clear-all   archive all channels and start fresh
    -clear-msg   remove single message by index [ --clear-msg <n> ]
    -trim <n>    archive messages older than n, keep recent n lines
    -archive     show archive list for current channel
    -channels    list all channels with last-active timestamps
    -models      list known models and their status

    keywords inside the message text :

        :#channel:         switch active channel
        :model:            switch active model
        :all:              broadcast next message to all models


##[ message clearing and archiving ]##########################################

    clearing never destroys history — it rotates it into the archive.

    clear sequence :

        1. compress active history to xz with timestamp filename
        2. move compressed archive to data/chat/archive/channel/<name>/
        3. truncate active history file to empty
        4. commit happens at next natural git commit [ not automatic ]

    --no-archive flag available for genuinely throwaway content.

    auto-rotation : when active history exceeds a configurable size threshold
    [ default 512 KB ], the older half is automatically archived and the
    recent half is kept. this prevents silent context bloat without
    requiring manual intervention.

    archive browsing :

        bin/chat -archive              list archives for current channel
        bin/chat -archive :#channel:   list archives for named channel
        xzcat data/chat/archive/channel/main/2026-05-14T15:32:11.xz | less


##[ consensus mode ]##########################################################

    :all: broadcasts the next message to every configured model in parallel
    and collects responses. output is presented as a side-by-side comparison :

        .: consensus round — job-site-scan :.

        [ kimi-code ]
          the fetch queue should use exponential backoff with jitter ...

        [ claude-code ]
          agreed on backoff — jitter avoids thundering herd. i would also ...

        [ amos-id ]
          backoff confirmed. suggest cap at 30s per host ...

    consensus results are stored in the channel history attributed to each
    model individually, preserving the full record for later analysis.

    this is a clean standalone test bed for consensus algorithms before
    they are integrated into the zenki infrastructure.


##[ async inbox model ]#######################################################

    models do not need to be running simultaneously. a model can post a
    message and exit — the other model reads it on next invocation.

    this makes bin/chat useful for :

        - async cross-model task handover
        - leaving notes between sessions
        - queueing questions for a model to answer when it next runs

    -wait-reply polls the history file until a reply appears from the
    target model, then exits with the reply content. timeout configurable.


##[ integration path ]########################################################

    phase 1 [ this script ] :
        file-backed, standalone, no zenki required.
        user + kimi + claude can all use it equally.

    phase 2 [ zenka integration ] :
        channels zenka takes over history management.
        bin/chat becomes a thin frontend to channels.cmd.post etc.
        routing and consensus move into the zenki network.

    phase 3 [ roaming sessions ] :
        self-contained zenka design (see topic-self-contained-zenka.md)
        chat sessions travel with commits across nodes.
        models running on remote nodes participate transparently.


##[ proposed expansions ]#####################################################

    1. silent annotations ( :note: prefix )
       messages starting with :note: are written to history but skip model
       dispatch. useful for leaving TODOs, context hints, or "ignore the stub
       above" markers without triggering another inference round.

    2. cross-channel references ( :→#channel: )
       inline syntax to quote the last N messages from another channel.
       when models roam between #job-site-scan and #design-discussion, they
       can pull context without copy-paste — channels stay honest.

    3. per-channel system persona
       a data/chat/channel/<name>/persona file containing plain-text context
       injected before the rolling history on dispatch. #debug gets terse
       technical voice, #docs gets narrative voice — channels become
       meaningfully different rather than just namespaces.

    4. search / grep across history ( -search / -grep )
       bin/chat -search "backoff" -c main returns matching lines with indices,
       so -clear-msg or -reply-to can target them. flat text is human-readable;
       search makes it machine-usable too.

    5. rolling model memory ( compress-and-summarize )
       when a channel history exceeds N lines, summarize the oldest M lines
       via the model itself, append the summary to
       data/chat/model/<name>/memory, and archive the raw lines. gives
       models persistent cross-channel context without unbounded growth.

    6. message threading ( :reply-to:N: )
       lightweight thread marker referring to history line index. in :all:
       consensus mode, replies can be shown side-by-side AND threaded,
       preventing flat-history confusion in long exchanges.


##[ open questions for kimi ]#################################################

    - preferred format for the history file : plain text vs JSONL vs custom ?
      plain text is most readable when committed ; JSONL is easier to parse.
      current proposal : plain text with parseable timestamp+caller prefix.

    - should :all: consensus results be stored once per round or once per
      model response ? ( per-model preferred for attribution )

    - kimi zenka upgrade scope : what interaction improvements would make
      bin/chat most convenient from the kimi coding shell ?

    - any concerns about the xz-on-clear approach vs a softer rotation ?


#############################################################################

#,,..,,,,,,,.,...,,..,,,.,.,,,...,...,,.,,,..,..,,...,...,...,,..,,.,,,.,,,,.,
#CVZPBA7PFL4GHQRLSGUL6QDVGGTBAVYQ3ZAAQNOJND4RES6BUI7XDOITJPPGIMVI53ZISKD3ILYIG
#\\\|EMGZ4WTY6PNELMFRGJEEPCAEV4UG43UDQUF4RXL66WCQCLIZ7J2 \ / AMOS7 \ YOURUM ::
#\[7]TQODFMYNYFK7MOKUFJ4NTYNBWAKEDYUPNW6DIHFOE3PXBWSIHUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
