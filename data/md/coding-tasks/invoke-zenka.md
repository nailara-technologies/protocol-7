## [:< ##

# task: invoke zenka — invoke.ai image generation API client

create the invoke zenka: an on-demand zenka that wraps the invoke.ai REST API
and provides image generation commands to other zenki (coding, models). it
assumes invoke.ai is already running (managed by invoke-web zenka).

the invoke.ai web server listens at http://127.0.0.1:9090. the invoke zenka
submits generation jobs, tracks them via polling, and routes completion
replies back to the caller.


## p7 code style (strictly enforced)

- lowercase comments, [ brackets ] for annotations, no capitals in comments
- `$ARG` not `$_`
- `<[module.name]>->($args)` — closing `]>` before `->`
- `<[module.name]>` with no args (parser adds `->()` automatically)
- `:flag:` not `--flag`
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules: `return { mode => 'size', data => $str }` for output
  `return { mode => 'false' }` for no-output/error fallback
  `$reply` is pre-declared as a hashref in cmd scope — use `my $out` for strings
- config: `$data{'invoke'}{'external.models.invokeai.url'}` (no 'cfg' key)
- do NOT generate any footer lines whatsoever — signing adds the full AMOS7 footer
- do NOT add `#,,...` stub lines
- syntax check with `ptd -c`, not `perl -c`
- new module header format: `## [:< ##\n\n# name  = ...\n# descr = ...`


## key reference files — read these first

    src/invoke-web.init_code          — pattern for init with LWP health check
    src/invoke-web.cmd.start          — IPC::Open3 spawn pattern (style ref)
    src/invoke-web.cmd.status         — status cmd pattern
    src/invoke-web.handler.check_health — timer handler pattern
    cfg/zenki/invoke-web/zenka.v7  — on-demand zenka config pattern
    cfg/external-inference-models — invokeai config keys


## invoke.ai REST API reference

base url: http://127.0.0.1:9090  (config: external.models.invokeai.url)
all requests use Content-Type: application/json

### health
    GET  /api/v1/app/version
    → { "version": "4.x.x" }

### model lookup
    GET  /api/v1/models/?model_type=main
    → { "models": [ { "key": "<uuid>", "name": "...", "base": "sd-1"|"sdxl",
                       "type": "main" }, ... ] }
    the "key" field (not name) is required in generation graphs.

### queue submission
    POST /api/v1/queue/default/enqueue_batch
    body: see invoke.api.build_graph below
    → { "batch": { "batch_id": "<uuid>", "graph": {...} },
        "enqueued": 1, "requested": 1,
        "queue_id": "default",
        "item_ids": [ <integer> ] }

### item status polling
    GET  /api/v1/queue/default/i/<item_id>
    → { "item_id": N, "status": "pending"|"in_progress"|"completed"|"failed"|"canceled",
        "completed_at": "...", "error": "...",
        "output": { "image": { "image_name": "<filename>" } } }  ## on completed

### image file path
    completed images live at: /home/taeki/.invokeai/outputs/images/<image_name>
    (use config key: external.models.invokeai.outputs — default to that path)
    HTTP download also available: GET /api/v1/images/<image_name>

### queue management
    GET  /api/v1/queue/default/status
    → { "pending": N, "in_progress": N, "completed": N, "failed": N }

    PUT  /api/v1/queue/default/cancel_by_batch_ids
    body: { "batch_ids": ["<batch_id>"] }

### OpenAPI spec (for uncertain endpoints)
    GET  /openapi.json  — full API spec, check this if anything is unclear


## invoke.ai graph structure (txt2img)

the enqueue_batch body follows this shape. build it in invoke.api.build_graph.
provide two variants: one for sd-1/sd-1.5, one for sdxl.

### sd-1 graph skeleton (simplified):
    nodes:
        main_model_loader   type=main_model_loader  model.key=<uuid>
        clip_skip           type=clip_skip           skipped_layers=0
        positive_cond       type=compel              prompt=<prompt>
        negative_cond       type=compel              prompt=""
        noise               type=noise               seed=<N> width=512 height=512
        denoise_latents     type=denoise_latents     cfg_scale=7.5 scheduler=euler steps=30
        l2i                 type=l2i
        save_image          type=save_image

    edges (source→destination field mappings):
        main_model_loader.unet        → denoise_latents.unet
        main_model_loader.clip        → clip_skip.clip
        clip_skip.clip_skip_output    → positive_cond.clip
        clip_skip.clip_skip_output    → negative_cond.clip
        positive_cond.conditioning    → denoise_latents.positive_conditioning
        negative_cond.conditioning    → denoise_latents.negative_conditioning
        noise.noise                   → denoise_latents.noise
        main_model_loader.vae         → l2i.vae
        denoise_latents.latents       → l2i.latents
        l2i.image                     → save_image.image

### sdxl graph skeleton:
    nodes:
        sdxl_model_loader   type=sdxl_model_loader  model.key=<uuid>
        positive_cond       type=sdxl_compel_prompt  prompt=<prompt> style=<prompt>
        negative_cond       type=sdxl_compel_prompt  prompt="" style=""
        noise               type=noise               seed=<N> width=1024 height=1024
        denoise_latents     type=denoise_latents     cfg_scale=7.0 scheduler=euler steps=30
        l2i                 type=l2i
        save_image          type=save_image

    edges:
        sdxl_model_loader.unet              → denoise_latents.unet
        sdxl_model_loader.clip              → positive_cond.clip
        sdxl_model_loader.clip2             → positive_cond.clip2
        sdxl_model_loader.clip              → negative_cond.clip
        sdxl_model_loader.clip2             → negative_cond.clip2
        positive_cond.conditioning          → denoise_latents.positive_conditioning
        positive_cond.pooled_conditioning   → denoise_latents.positive_conditioning_2
        negative_cond.conditioning          → denoise_latents.negative_conditioning
        negative_cond.pooled_conditioning   → denoise_latents.negative_conditioning_2
        noise.noise                         → denoise_latents.noise
        sdxl_model_loader.vae               → l2i.vae
        denoise_latents.latents             → l2i.latents
        l2i.image                           → save_image.image

    note: if uncertain about exact field names, consult /openapi.json from the
    running invoke.ai instance. add an inline comment where assumptions were made.


## files to create

### cfg/zenki/invoke/zenka.v7

on-demand zenka. starts when queried, shuts down after 5-minute idle timeout.

    .:[ invoke.ai image generation api client zenka ]:.

    [load_config_file:'shared-params']
    [load_config_file:'external-inference-models']

    system.zenka.verbosity.buffer  = 2
    system.zenka.verbosity.logfile = 2
    system.zenka.verbosity.console = 2

    start.on-demand    = 1
    restart.disabled   = 1
    heartbeat.disabled = 1

    ## idle timeout: 5 minutes ##
    [base.zenki.set_ondemand_timeout:300]

    access.cmd.usr.cube = heart verify-instance commands reload \
                          show-buffer show-access \
                          generate queue-status cancel list-images status health

    modules.load = auth net protocol io.unix invoke

    [load_modules:<modules.load>]
    [init_modules]

    [root.drop_privs:<system.amos-zenka-user>]

    [base.net.connect:'unix']

    [get_session_id]

    [zenka.loop]


### cfg/zenki/invoke/subroutine.white-list

look at cfg/zenki/invoke-web/subroutine.white-list for exact format.

    invoke.init_code
    invoke.cmd.generate
    invoke.cmd.queue-status
    invoke.cmd.cancel
    invoke.cmd.list-images
    invoke.cmd.status
    invoke.cmd.health
    invoke.handler.poll_jobs
    invoke.api.build_graph


### src/invoke.init_code

    # name  = invoke.init_code
    # descr = invoke zenka initialization

    - load LWP::UserAgent and JSON modules via base.perlmod.autoload (one at a time)
    - initialize state:
        $data{'invoke'}{'status'}       = 'idle'
        $data{'invoke'}{'url'}          = config 'external.models.invokeai.url'
                                          // 'http://127.0.0.1:9090'
        $data{'invoke'}{'outputs_dir'}  = '/home/taeki/.invokeai/outputs/images'
        $data{'invoke'}{'default_model'}= config 'external.models.invokeai.default_model'
                                          // 'stable-diffusion-xl-base-1.0'
        $data{'invoke'}{'jobs'}         = {}  ## item_id => { batch_id, prompt, caller_reply }
        $data{'invoke'}{'model_cache'}  = {}  ## name => { key, base }

    - do a quick health check: GET $url/api/v1/app/version with 3s timeout
        if 200: log "invoke.ai reachable at $url [version: $ver]"
        if fail: log "invoke.ai not reachable at $url — start invoke-web zenka first"
        either way: proceed (invoke.ai may not be running yet)

    - schedule job poll timer: every 3 seconds
        <[event.add_timer]>->({
            'after'    => 5,
            'interval' => 3,
            'repeat'   => TRUE,
            'handler'  => 'invoke.handler.poll_jobs',
        })

    - log initialization complete


### src/invoke.api.build_graph

    # name  = invoke.api.build_graph
    # descr = construct invoke.ai enqueue_batch request body for txt2img

    my $params = $ARG // {};
    my $prompt  = $params->{'prompt'}  // '';
    my $seed    = $params->{'seed'}    // int(rand(2**31));
    my $steps   = $params->{'steps'}   // 30;
    my $cfg     = $params->{'cfg'}     // 7.0;
    my $width   = $params->{'width'}   // 1024;
    my $height  = $params->{'height'}  // 1024;
    my $model_key  = $params->{'model_key'}  // '';
    my $model_base = $params->{'model_base'} // 'sdxl';  ## 'sd-1' or 'sdxl'

    build the appropriate graph hashref based on $model_base:
    - 'sdxl': use sdxl graph skeleton from API reference above
    - 'sd-1': use sd-1 graph skeleton (default width/height to 512)

    each node is a hashref under $graph{'nodes'}{$node_id}.
    edges is an arrayref of { source => { node_id, field }, destination => { node_id, field } }.
    give each graph a unique id: sprintf("txt2img_%d", $seed)

    return the full enqueue_batch body hashref:
    {
        'prepend' => JSON::false,
        'batch' => {
            'graph' => $graph,
            'runs'  => 1,
        }
    }


### src/invoke.cmd.generate

    # name  = invoke.cmd.generate
    # descr = cmd: submit an image generation request to invoke.ai

    parse $call->{'args'} — supports two forms:
        "a red cat sitting on a table"                  ## positional prompt
        "prompt=a red cat model=SDXL-v1 steps=20 seed=42 width=1024 height=1024"

    parsing logic:
        if args contains '=' then key=value mode
        else treat entire string as prompt, use defaults

    ## check invoke.ai is reachable before building graph ##
    my $url  = $data{'invoke'}{'url'};
    my $ua   = LWP::UserAgent->new( timeout => 5 );
    my $ping = $ua->get("$url/api/v1/app/version");
    unless ( $ping->is_success ) {
        return { mode => 'size',
                 data => "invoke.ai not reachable [ start with: p7c invoke-web.start ]\n" };
    }

    ## look up model key if not cached ##
    my $model_name = $params{'model'} // $data{'invoke'}{'default_model'};
    my $model_info = $data{'invoke'}{'model_cache'}{$model_name};
    unless ( $model_info ) {
        ## GET /api/v1/models/?model_type=main, find by name, cache result ##
        my $resp = $ua->get("$url/api/v1/models/?model_type=main");
        if ( $resp->is_success ) {
            my $data = decode_json( $resp->decoded_content );
            for my $m ( @{ $data->{'models'} // [] } ) {
                next unless ( $m->{'name'} // '' ) eq $model_name;
                $model_info = { key => $m->{'key'}, base => $m->{'base'} };
                $data{'invoke'}{'model_cache'}{$model_name} = $model_info;
                last;
            }
        }
        unless ( $model_info ) {
            return { mode => 'size',
                     data => "model not found in invoke.ai [ $model_name ]\n" };
        }
    }

    ## build graph and submit ##
    my $graph_body = <[invoke.api.build_graph]>->({
        prompt     => $params{'prompt'},
        seed       => $params{'seed'}   // int(rand(2**31)),
        steps      => $params{'steps'}  // 30,
        cfg        => $params{'cfg'}    // 7.0,
        width      => $params{'width'}  // 1024,
        height     => $params{'height'} // 1024,
        model_key  => $model_info->{'key'},
        model_base => $model_info->{'base'},
    });

    my $body_json = encode_json($graph_body);
    my $req = HTTP::Request->new( POST => "$url/api/v1/queue/default/enqueue_batch" );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($body_json);
    my $resp = LWP::UserAgent->new( timeout => 30 )->request($req);

    unless ( $resp->is_success ) {
        return { mode => 'size',
                 data => sprintf "submit failed [ %s ]\n", $resp->status_line };
    }

    my $result   = decode_json( $resp->decoded_content );
    my $batch_id = $result->{'batch'}{'batch_id'} // '';
    my $item_id  = ( $result->{'item_ids'} // [] )->[0] // '';

    ## store job for poll_jobs to track ##
    $data{'invoke'}{'jobs'}{$item_id} = {
        'batch_id'    => $batch_id,
        'prompt'      => $params{'prompt'},
        'model'       => $model_name,
        'queued_at'   => <[base.time]>->(3),
        'status'      => 'pending',
    };

    <[base.logs]>->( 1, 'invoke: queued [item:%s batch:%s]', $item_id, $batch_id );

    return { mode => 'size',
             data => sprintf "queued [item:%s] — poll with: p7c invoke.queue-status\n",
                 $item_id };


### src/invoke.cmd.queue-status

    # name  = invoke.cmd.queue-status
    # descr = cmd: show invoke.ai queue status and tracked jobs

    my $url = $data{'invoke'}{'url'};
    my $ua  = LWP::UserAgent->new( timeout => 5 );
    my $out = '';

    ## live queue stats from invoke.ai ##
    my $resp = $ua->get("$url/api/v1/queue/default/status");
    if ( $resp->is_success ) {
        my $s = decode_json( $resp->decoded_content );
        $out .= sprintf "queue : pending=%d in_progress=%d completed=%d failed=%d\n",
            $s->{'pending'} // 0, $s->{'in_progress'} // 0,
            $s->{'completed'} // 0, $s->{'failed'} // 0;
    } else {
        $out .= "queue : invoke.ai unreachable\n";
    }

    ## tracked jobs in this session ##
    my %jobs = %{ $data{'invoke'}{'jobs'} // {} };
    if (%jobs) {
        $out .= "\ntracked jobs:\n";
        for my $item_id ( sort keys %jobs ) {
            my $j = $jobs{$item_id};
            $out .= sprintf "  item:%-8s  %-12s  %s\n",
                $item_id, $j->{'status'}, $j->{'prompt'} // '';
        }
    } else {
        $out .= "no tracked jobs this session\n";
    }

    return { mode => 'size', data => $out };


### src/invoke.cmd.cancel

    # name  = invoke.cmd.cancel
    # descr = cmd: cancel a job by item_id, or all pending jobs

    my $target = $call->{'args'} // '';
    $target =~ s|^\s+|\s+$||g;

    my $url = $data{'invoke'}{'url'};
    my $ua  = LWP::UserAgent->new( timeout => 10 );

    if ( !length $target || $target eq 'all' ) {
        ## cancel all — collect batch_ids from tracked jobs ##
        my @batch_ids = map { $_->{'batch_id'} }
            values %{ $data{'invoke'}{'jobs'} // {} };

        unless (@batch_ids) {
            return { mode => 'size', data => "no tracked jobs to cancel\n" };
        }

        my $body = encode_json({ 'batch_ids' => \@batch_ids });
        my $req  = HTTP::Request->new(
            PUT => "$url/api/v1/queue/default/cancel_by_batch_ids" );
        $req->header( 'Content-Type' => 'application/json' );
        $req->content($body);
        my $resp = $ua->request($req);

        $data{'invoke'}{'jobs'} = {};  ## clear tracked jobs ##
        return { mode => 'size',
                 data => $resp->is_success ? "cancelled all jobs\n"
                                           : sprintf "cancel failed [ %s ]\n",
                                                 $resp->status_line };
    }

    ## cancel specific item — find its batch_id ##
    my $job = $data{'invoke'}{'jobs'}{$target};
    unless ($job) {
        return { mode => 'size', data => "unknown item_id [ $target ]\n" };
    }

    my $body = encode_json({ 'batch_ids' => [ $job->{'batch_id'} ] });
    my $req  = HTTP::Request->new(
        PUT => "$url/api/v1/queue/default/cancel_by_batch_ids" );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($body);
    my $resp = $ua->request($req);

    delete $data{'invoke'}{'jobs'}{$target};
    return { mode => 'size',
             data => $resp->is_success ? "cancelled item $target\n"
                                       : sprintf "cancel failed [ %s ]\n",
                                             $resp->status_line };


### src/invoke.cmd.list-images

    # name  = invoke.cmd.list-images
    # descr = cmd: list recently generated images from invoke.ai

    my $limit = int( $call->{'args'} // 20 );
    $limit = 20 unless $limit > 0 && $limit <= 200;

    my $url  = $data{'invoke'}{'url'};
    my $ua   = LWP::UserAgent->new( timeout => 10 );
    my $resp = $ua->get("$url/api/v1/images/list?limit=$limit&order_by=created_at&order_dir=DESC");

    unless ( $resp->is_success ) {
        return { mode => 'size',
                 data => sprintf "list failed [ %s ]\n", $resp->status_line };
    }

    my $data   = decode_json( $resp->decoded_content );
    my @images = @{ $data->{'items'} // [] };

    unless (@images) {
        return { mode => 'size', data => "no images found\n" };
    }

    my $out = '';
    for my $img (@images) {
        my $name    = $img->{'image_name'}  // '';
        my $created = $img->{'created_at'}  // '';
        my $width   = $img->{'width'}       // 0;
        my $height  = $img->{'height'}      // 0;
        ## shorten timestamp to date+time ##
        $created =~ s|T| |; $created =~ s|\.\d+.*$||;
        $out .= sprintf "%-40s  %dx%d  %s\n", $name, $width, $height, $created;
    }

    return { mode => 'size', data => $out };


### src/invoke.cmd.status

    # name  = invoke.cmd.status
    # descr = cmd: show invoke zenka status and invoke.ai reachability

    my $url     = $data{'invoke'}{'url'}          // '-';
    my $model   = $data{'invoke'}{'default_model'} // '-';
    my $pending = scalar keys %{ $data{'invoke'}{'jobs'} // {} };

    ## live reachability check ##
    my $ua      = LWP::UserAgent->new( timeout => 3 );
    my $resp    = $ua->get("$url/api/v1/app/version");
    my $version = '-';
    my $reach   = 'unreachable';
    if ( $resp->is_success ) {
        my $d = decode_json( $resp->decoded_content );
        $version = $d->{'version'} // '-';
        $reach   = 'ok';
    }

    my $out = sprintf
        "invoke.ai : %s\nversion   : %s\nurl       : %s\nmodel     : %s\njobs      : %d tracked\n",
        $reach, $version, $url, $model, $pending;

    return { mode => 'size', data => $out };


### src/invoke.cmd.health

    # name  = invoke.cmd.health
    # descr = cmd: quick invoke.ai HTTP health check

    same pattern as invoke.cmd.status but terser:
        "healthy: v4.x.x\n"  or  "unreachable: <error>\n"


### src/invoke.handler.poll_jobs

    # name  = invoke.handler.poll_jobs
    # descr = periodic timer: poll invoke.ai for job completion

    ## called every 3 seconds by repeating timer ##
    my %jobs = %{ $data{'invoke'}{'jobs'} // {} };
    return unless %jobs;

    my $url = $data{'invoke'}{'url'};
    my $ua  = LWP::UserAgent->new( timeout => 5 );

    for my $item_id ( keys %jobs ) {
        my $job  = $jobs{$item_id};
        next if ( $job->{'status'} // '' ) =~ m|^completed|failed|canceled$|;

        my $resp = $ua->get("$url/api/v1/queue/default/i/$item_id");
        unless ( $resp->is_success ) {
            <[base.logs]>->( 2, 'invoke: poll failed for item %s', $item_id );
            next;
        }

        my $item   = decode_json( $resp->decoded_content );
        my $status = $item->{'status'} // 'pending';

        $job->{'status'} = $status;

        if ( $status eq 'completed' ) {
            my $image_name = eval {
                $item->{'output'}{'image'}{'image_name'} } // '';
            my $outputs_dir = $data{'invoke'}{'outputs_dir'};
            my $image_path  = "$outputs_dir/$image_name";

            <[base.logs]>->(
                1, 'invoke: item %s complete [ %s ]', $item_id, $image_name );

            ## log elapsed time ##
            if ( defined $job->{'queued_at'} ) {
                my $elapsed = <[base.time]>->(3) - $job->{'queued_at'};
                <[base.logs]>->( 1, ':. elapsed: %.1fs', $elapsed );
            }

            delete $data{'invoke'}{'jobs'}{$item_id};

        } elsif ( $status eq 'failed' ) {
            my $error = $item->{'error'} // 'unknown error';
            <[base.logs]>->( 0, 'invoke: item %s failed [ %s ]', $item_id, $error );
            delete $data{'invoke'}{'jobs'}{$item_id};

        } elsif ( $status eq 'canceled' ) {
            delete $data{'invoke'}{'jobs'}{$item_id};
        }
        ## pending/in_progress: leave in jobs hash, poll again next tick ##
    }


## note on caller reply (future wiring)

    the current design logs completion but does not route replies back to the
    caller — the caller polls with queue-status or list-images. if async
    notification is needed later, store a reply route in the job hash during
    generate (caller session_id + handler name), then use
    <[base.protocol-7.route-send]> in poll_jobs to deliver the image path.
    this is left for the next iteration to keep the first version simple.


## verify

    ptd -c on all 9 module files
    check zero footer lines in all files
    check subroutine.white-list format matches cfg/zenki/invoke-web/subroutine.white-list
    check cfg/zenki/invoke/zenka.v7 loads modules.load = auth net protocol io.unix invoke

    do not attempt to run — requires live invoke.ai instance.
    note any uncertain API field names as inline comments.

#,,.,,,.,,.,.,,,.,,..,.,,,...,,.,,...,...,,,,,..,,...,.,.,...,,,.,,..,...,.,,,
#ZQ3FVIBPFDEAHT7UOZQO6DGXOJFF5NZDJ2V2ZT4X4CSX676WC7H72R2KJ3MWWSDDIS7TB57LWFUSK
#\\\|TLB4F532XYUXZ6K46RLSOJ6Y766D4AIVQGLTTPJM4XTXJVRYD3J \ / AMOS7 \ YOURUM ::
#\[7]EMY3OFHKHE2GZAB7BWG3X2YPCFRKVH6ZZEWELWDOU3LPB7C2OMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
