# P156 isolated shared cache port fit preparation

Prepared, NOT launched: `scripts/cpu/fit_shared_pair_port.sh`. Archive target `scratch/p156_shared_pair_port_fit_20260921`. This builds P109 core/P120 pipeline/P151 cache at seed25 with the existing development CDROM_OFF/ETHERNET_OFF settings and aggressive routability optimization. It refuses mismatched sources/settings, an active Quartus process or a reused archive.

Purpose: measure whether P151's shared RAM write/paired-read port removes the mirrored RAM blocks and reduces routing congestion. Its CPU integration, Whetstone and Dhrystone evidence is recorded in P151's document; Whetstone costs0.579% while Dhrystone is unchanged. Neither RAM inference nor area/timing savings have been demonstrated. Keeping the CPU unchanged isolates this cache tradeoff before integrating P153/P154.

Do not promote cache HDL or launch until P150's entire existing wrapper, including reports/source checks, is terminal and root reviews its fresh result. The wrapper never applies patches or deploys hardware. It requires the exact P151 source already promoted deliberately in this checkout. Before launch verify machinewide Quartus idleness, source/config hashes and current git commit; freeze all tracked HDL/QSF/QIP/SDC through the whole wrapper.

After mapping inspect the RAM summary for both expected block count and bank inference; after fitting inspect fresh artifact, CPU/RAM/HDMI/cross-domain timing and input manifest. Never treat stale output_files reports/RBF as this candidate. No fit, timing or hardware result yet.
