# Cross-domain and write-queue timing evidence

The supplemental queue STA used the unchanged production timing constraints. The archived collection log and individual reports are under `scratch/timequest_wq_interim_mac_wqmlab/`; `queue_sta.exit=0`. Every listed collection had zero violated paths.

| Path set | Setup paths / worst slack | Hold paths / worst slack |
|---|---:|---:|
| sys→ram queue captures | 64 / +3.606 ns | 64 / +0.642 ns |
| ram→ram queue captures | 64 / +0.970 ns | 64 / +1.398 ns |
| sys→ram queue pointers | 4 / +1.190 ns | 4 / +4.918 ns |
| ram→sys queue pointers | 4 / +2.572 ns | 4 / +4.346 ns |

Queue capture endpoint collections resolved to 28 `a_ram`, 32 `d_ram`, and 4 `be_ram` registers. The optional internal MLAB register and pin collections were empty: Quartus did not expose named `wq_mem` internal endpoints. The captures include memory-output paths into the registered queue endpoints, but the empty collections do not establish separate coverage of every internal MLAB register or pin.

The full-fit TimeQuest summary reports minimum setup slack by domain: CPU −2.406 ns (TNS −298.902 ns), SDRAM −0.697 ns (TNS −1.553 ns), HDMI −0.426 ns (TNS −2.716 ns). Minimum overall hold slack was +0.200 ns (hold TNS 0). The worst SDRAM path was `sdram:sdram|bank_age[0][1]` → `sdram:sdram|chip`, outside the write-queue datapath. These results explain why the full fitter completed but the wrapper timing gate failed; the artifact is timing-marginal and is not a timing-clean release.
