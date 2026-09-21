# P130 spanning-read data selection timing experiment

The completed P120/P124 fit uses 39,795 ALMs, 25,702 registers, 482 RAM blocks and 42 DSPs. CPU setup slack is -0.188 ns, RAM +0.483 ns and HDMI +0.323 ns. The worst CPU path runs from tc[14] through MMU request qualification, fast_span_ack, pipeline load data/flags and branch-prefetch seeding to epf_data[5][15]. This is not the older PEA address ALU timing path.

P130 leaves acknowledgement unchanged but selects the spanning read data from registered transaction state (C_LOOK, look2, r_span2, data bank). Request/snoop/error checks still qualify acceptance; they no longer select the data mux. Intended effect is timing only, without changing accepted data or cycle count. Source `scratch/p130_span_data_select_20260921/ap040_cache.v`; unapplied patch `scripts/cpu/span_data_select.patch` over P124. Simulation, exact-ack/error/CE/snoop checks and a new fit remain required. No timing improvement is claimed until measured.
