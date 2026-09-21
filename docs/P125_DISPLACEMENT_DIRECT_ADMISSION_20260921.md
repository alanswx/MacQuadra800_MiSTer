# P125 displacement loads with direct admission

UNQUALIFIED isolated reevaluation of P116 on P120's cheaper pipeline admission and P124's earlier spanning-read response. P116 alone regressed Whetstone by 0.78% and remains parked; a change in entry/load cost motivates measuring this combination, not assuming the old result reverses. No production RTL is changed.

Core scratch/p125_displacement_direct_admit_20260921/ap040_core.v is the exact P116 core, SHA256 12ca13c0a335a7cad55b61396df6f8f48ea55086512491da61e43cd4f16200ec. Pipeline in the same directory has SHA256 638bf6cab9ee449c2a8ea33586f23f829fd7b569f182f73098c2738b5e66c12a. Cache is the isolated P124 e50de9fea12d116ffba6edcf3b0b01ff17f8f8e1a1cb7032e0073f2c2cb38465. Reproducible patch scripts/cpu/displacement_direct_admit.patch applies to P109 core and P120 pipeline.

Adds signed d16 MOVE/MOVEA loads to the existing pipeline load path, retaining extension validity, size and destination guards. Measure both original Whetstone and Dhrystone against the P120/P124 combination; a gain still requires displacement-specific register/extension/fault/IRQ tests, full integration and FPGA timing/area qualification. No performance claim yet.
