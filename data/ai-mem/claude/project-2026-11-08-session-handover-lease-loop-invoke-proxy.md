---
name: session-handover-lease-loop-invoke-proxy
description: START HERE 2026-11-08 : gpu lease loop with models on hold fixed, invoke.ai proxy + restart requeue, qwen21 install carries the legacy models [ one image pool ] ; what is open
metadata:
  type: project
---

session 2026-11-08 [ follows [[session-handover-n7fs-format3]] ].

done, pushed to hub [ coding commits pulled on srv-U F V A + azurum, coding reloaded U A azurum ] :
- 4016d295d a models ON HOLD looped invoke-web + coding : a blocked start answers FALSE, the acquire reply took it as an answer -> a request per processor poll [ ~1\s ] + a queue pause \ resume per retry. now : FALSE = no answer, backoff 30 s doubling, an invoke-web retry is a probe [ no pause ] ; coding model_path_reply \ switch_model_reply read FALSE replies via base.reply.mode_text [ was an empty YAML parse failed ]
- 418b1c9c7 backoff cap 780 s [ owner : 600 s timers are avoided ]
- e4a02d350 + 832c83305 + 0c985f19f invoke-web.proxy [ empty \ none \ url ; url in host-config/invoke-web.cfg ] -> http[s]_proxy + INVOKEAI_DOWNLOAD_PROXY ; socks needs pysocks socksio [ warn at start, todo QZE for an os/pip dep kind ] ; a start waiting for the lease starts without it when models is silent, keeps its args
- 899422394 a plain restart retries the item it interrupted [ restart recovery kind ]
- qwen21 now holds the legacy loras [ 176 ], ip adapters + encoders [ renamed to the names invoke looks up ], perfection-super \ -asian completed via fetch-files, two qwen loras rekeyed -- see [[invokeai-model-install-quirks]]

open :
- owner holds models\task [ do not release ]
- owner : delete in the qwen21 ui the 'unknown' FLUX Redux entry and the two old unknown qwen lora entries [ converted copies are installed ]
- todo QZE [ p7-deps os/pip kind ] ; carried over : XAH shorten, start_once mismatch todo, "render queue empty" repeats, first render loop step [ [[render-pipeline-direction]] ]
- next big step per owner : after N7FS is usable

#,,.,,,,.,,,,,,..,.,.,,..,.,.,..,,,,,,.,.,.,,,..,,...,...,,,.,,.,,...,.,.,,..,
#33LSJ532WEEORBYEMEKTTX3UCATOL3UND4NEDWKKDUTGEX2GJQGXTH4OVHWMSDQID7GU2O7MLGZIK
#\\\|Y5QQEK5C2ZID3NPWDKSPNCVIGZF3SJE5KDFP2P4OXCT4DPIFAGL \ / AMOS7 \ YOURUM ::
#\[7]KS3GFQVMDVC5XGU7LQWIYZQQSQHZQ4VXWIM33WAF2ZC22YGVEWDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
