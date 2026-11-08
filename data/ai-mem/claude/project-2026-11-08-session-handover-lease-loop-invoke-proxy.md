---
name: session-handover-lease-loop-invoke-proxy
description: START HERE 2026-11-08 : gpu lease loop with models on hold fixed, invoke.ai proxy + restart requeue, qwen21 install carries the legacy models [ one image pool ] ; what is open
metadata:
  type: project
---

session 2026-11-08 [ follows [[session-handover-n7fs-format3]] ].

done, pushed to hub [ coding commits pulled on srv-U F V A + azurum, coding reloaded U A azurum ] :
- 58bb4389b a models ON HOLD looped invoke-web + coding : a blocked start answers FALSE, the acquire reply took it as an answer -> a request per processor poll [ ~1\s ] + a queue pause \ resume per retry. now : FALSE = no answer, backoff 30 s doubling, an invoke-web retry is a probe [ no pause ] ; coding model_path_reply \ switch_model_reply read FALSE replies via base.reply.mode_text [ was an empty YAML parse failed ]
- b0a0b78d6 backoff cap 780 s [ owner : 600 s timers are avoided ]
- d1e34e381 + 11c753ac2 + 999a16459 invoke-web.proxy [ empty \ none \ url ; url in host-config/invoke-web.cfg ] -> http[s]_proxy + INVOKEAI_DOWNLOAD_PROXY ; socks needs pysocks socksio [ warn at start, todo QZE for an os/pip dep kind ] ; a start waiting for the lease starts without it when models is silent, keeps its args
- 899422394 a plain restart retries the item it interrupted [ restart recovery kind ]
- qwen21 now holds the legacy loras [ 176 ], ip adapters + encoders [ renamed to the names invoke looks up ], perfection-super \ -asian completed via fetch-files, two qwen loras rekeyed -- see [[invokeai-model-install-quirks]]

open :
- owner holds models\task [ do not release ]
- owner : delete in the qwen21 ui the 'unknown' FLUX Redux entry and the two old unknown qwen lora entries [ converted copies are installed ]
- todo QZE [ p7-deps os/pip kind ] ; carried over : XAH shorten, start_once mismatch todo, "render queue empty" repeats, first render loop step [ [[render-pipeline-direction]] ]
- next big step per owner : after N7FS is usable

#,,,,,,,,,,.,,,,,,,,.,..,,..,,...,.,,,,..,...,..,,...,...,...,,,,,..,,,..,,.,,
#4D32DO6FZHA4JI433KVCOTFYE7BULFBR2FK3JQ7CZ63SBZYBBMNA3VWMXKNY5EWLSBW4JEYTSPIOW
#\\\|A2OPRSGANQEAEX52JJYD6V2MOS3MLKOWRYNEIACCUTJKSPB3VPX \ / AMOS7 \ YOURUM ::
#\[7]QNRWNWHM6VW4GIWY4TEYNR7O2OG4COIRDKUWPQFMKE7CHIQSNQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
