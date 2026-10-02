# invoke-ai qwen 2.1 fork : negative vram model budget

brief [ 2026-10-02 ]. measured, fix untested. details :
`data/ai-mem/claude/project-2026-10-02-invoke-render-degradation-baseline.md`
[ "reference images vs qwen 2.1" ].

## finding

the fork's `~/.invokeai-qwen21/invokeai.yaml` has `max_cache_vram_gb: 5`
+ `device_working_mem_gb: 5`. the log shows a negative model budget for
both the 8.3 GB qwen3-vl encoder and the transformer :

```
Loading 0.0 MB into VRAM, but only -11.09 MB were requested.
```

while ~11 GB of vram sat free. effect : the encoder phase ran on ~1 cpu
core at 97 %, gpu at 3 % ; with 5 references the denoise was pcie-bound
[ ~73 W, ~11 GB/s rx ] instead of compute-bound [ 142 W with 1 reference ].

## work

1. one change at a time, restart the fork between changes :
   - `max_cache_vram_gb` 5 -> 6 -> 7 -> 8, or
   - `device_working_mem_gb` 5 -> 4 -> 3
2. per step : same graph [ 1 reference and 5 references ], record via
   `p7c invoke-web.render-stats` + `nvidia-smi dmon -s pt` : encoder
   seconds, denoise seconds, watts, pcie rx, log budget line
3. stop when the budget warning shows a positive amount and the encoder
   runs on the gpu
4. watch for the wsl overcommit case [ the 5 gb cap was set after a
   "21.65 GiB allocated by PyTorch" oom ] and screen vram [ ~1.7 GB for 3
   screens ]

## careful

- keep a backup of the yaml before each change
- gpu fan : real compute load means ~142 W \ 80 °C+ ; the fan bearing
  issue is under warranty [ `project-host-pc-warranty-until-2027-02.md` ]

#,,,.,,..,,,.,,..,,..,,..,,,.,.,,,.,,,,..,.,.,..,,...,...,...,,,.,,,,,,..,...,
#6SBMZCQXNS7UP5IHRJECCYNO4CXW3SQKW5ADIHODSYDM5L2OPW3D4YEVSM2KY3QZZUMNPML4VY43C
#\\\|ZVHJYPX5DXYZV5LSZN63HDMLLMLTYG36HYBNPL55GVOCEJDBP5P \ / AMOS7 \ YOURUM ::
#\[7]ESPIMDFLZ4NUMXKDHNRBICJJF3XF442EFFSLEG2SY5JGZSCCY6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
