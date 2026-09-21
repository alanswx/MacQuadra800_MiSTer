# P147 state-based cache response-data selection

Unqualified timing candidate over P136 cache, SHA256 `415efd9b2b96eb0972e6f3f75bf8b7ecd85e43b9e2aa78313de9256f1ff54aa3` at `scratch/p147_cache_response_data_20260921/ap040_cache.v`. Patch `scripts/cpu/cache_response_data_select.patch`.

P136 fits at 40,228 ALMs and 502 RAM blocks, but CPU setup is -5.481 ns. Root inspected the actual 32-level worst path: MMU ATC RAM/tag selection and physical address qualification drive fast_ifetch_idle, which selects c_rdata, then pipeline load ALU/flags and branch-refill writes into epf_data. Live request qualification therefore selects DATA values even when its qualified instruction-read arm cannot be accepted.

P147 keeps every acknowledge/error condition unchanged and selects data from response state plus request/hint shape. C_IDLE with ack_r retains rdata_r; other idle reads select instruction data or the hinted aligned/pair data. C_LOOK instruction/data/paired responses select from registered transaction shape. Unacknowledged data may differ and is not valid response evidence. Timing improvement requires a new fit. Before promotion, require cycle-identical acknowledgements and accepted data, cache snoop/error/CE/no-gap regressions, full CPU integration and identical workload cycles/captures.
