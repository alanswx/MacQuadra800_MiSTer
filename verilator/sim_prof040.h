#ifndef SIM_PROF040_H
#define SIM_PROF040_H
// Exact-workload profiler for the dual-issue core (CPU_AP68040 builds).
//
// One sample per rising edge after eval while the bracket is active.  The
// transactions are tracked at the core's own bus -- the 68040 pins behind
// quadra_cpu040's TS/TA conversion, before the external store buffer --
// because that is what the core waits on; the platform side is sampled
// separately for the VRAM beat stream.  Every "stall reason" below is a
// heuristic from sampled state and is labelled as such in the report.
//
// Sections of the report (tab separated, one keyword per line):
//   SUMMARY   cycles, retirements, IPC
//   RETIRE    retirements per cycle histogram
//   BUSY      cycles with a core-side transfer outstanding, by class, and
//             the retirements that still happened under them
//   STALL     zero-retire cycles by heuristic reason
//   XACT      transactions by class: count, cycles, mean/max latency
//   LAT       latency histogram per class
//   ROMCACHE  direct-mapped / 2-way external ROM cache miss rates for the
//             ROM line stream the core's own caches let through
//   VRAM      store sizes/alignment, read-cache hit estimate, write deltas,
//             inter-arrival histogram
//   WINDOW    per-2^20-cycle time series
//   TRAP      cycles by the trap whose entry precedes the retired PC
//   HOT       hottest 16-byte PC buckets with a short disassembly
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <map>
#include <unordered_map>
#include <algorithm>

struct Prof040Sample {
	bool     retire = false, retire2 = false;   // WB retired one / a second-slot instruction
	uint32_t retired_pc = 0;                    // PC of the last retired instruction (one clock late)
	bool     c_req = false, c_ack = false, c_last = false;
	bool     c_write = false, c_instr = false, c_line = false;
	uint8_t  c_size = 0;                        // 0 byte, 1 word, 2 long / line beat
	uint32_t c_addr = 0;
	bool     m_req = false, m_ack = false, m_write = false;
	uint32_t m_addr = 0;
	bool     sb_pending = false;                // the external store buffer holds a store
	bool     vram_wp = false;                   // the platform's direct VRAM write pulse
	uint8_t  qcnt = 0;                          // decoder queue words
	bool     dmu_busy = false;                  // the DMU engine is not quiet
};

class Prof040 {
public:
	enum Region { R_RAM, R_ROM, R_VRAM, R_DAFB, R_IO, R_OTHER, R_N };
	enum Kind { K_IF, K_DR, K_DW, K_N };
	static const int NCLASS = K_N * R_N;
	enum Stall { ST_IF_ROM, ST_IF_RAM, ST_IF_OTHER, ST_DR_VRAM, ST_DR_RAM, ST_DR_ROM, ST_DR_OTHER,
	             ST_DW_VRAM, ST_DW_RAM, ST_DW_OTHER, ST_DMU_NOBUS, ST_SB_NOBUS, ST_FETCH_STARVED, ST_INTERNAL, ST_N };

	static const char* region_name(int r) {
		static const char* n[R_N] = {"ram", "rom", "vram", "dafb", "io", "other"};
		return n[r];
	}
	static const char* kind_name(int k) {
		static const char* n[K_N] = {"ifetch", "dread", "dwrite"};
		return n[k];
	}
	static const char* stall_name(int s) {
		static const char* n[ST_N] = {
			"wait_ifetch_rom", "wait_ifetch_ram", "wait_ifetch_other",
			"wait_dread_vram", "wait_dread_ram", "wait_dread_rom", "wait_dread_other",
			"wait_dwrite_vram", "wait_dwrite_ram", "wait_dwrite_other",
			"dmu_busy_no_bus", "storebuf_pending_no_bus", "fetch_queue_empty", "internal"};
		return n[s];
	}
	static int region_of(uint32_t a) {
		if ((a >> 30) == 0) return R_RAM;
		if ((a >> 28) == 4) return R_ROM;
		if ((a >> 21) == (0xF9000000u >> 21)) return R_VRAM;      // $F900_0000-$F91F_FFFF
		if ((a >> 10) == (0xF9800000u >> 10)) return R_DAFB;
		if ((a >> 28) == 5) return R_IO;
		return R_OTHER;
	}

	// An N-way LRU cache of 16-byte lines, for the external ROM cache sweep.
	struct CacheSim {
		std::string name;
		unsigned ways = 1, sets = 1, set_shift = 0;
		std::vector<uint32_t> tag;      // sets*ways, 0xFFFFFFFF = empty
		std::vector<uint8_t>  age;      // LRU rank, 0 = most recent
		uint64_t refs = 0, misses = 0;
		void init(const std::string& nm, unsigned bytes, unsigned w) {
			name = nm; ways = w; sets = bytes / 16 / w;
			set_shift = 0; while ((1u << set_shift) < sets) set_shift++;
			tag.assign(sets * ways, 0xFFFFFFFFu); age.assign(sets * ways, 0);
			refs = misses = 0;
		}
		void access(uint32_t line) {
			refs++;
			const unsigned s = line & (sets - 1);
			const uint32_t t = line >> set_shift;
			uint32_t* tg = &tag[s * ways]; uint8_t* ag = &age[s * ways];
			unsigned hit = ways;
			for (unsigned w = 0; w < ways; w++) if (tg[w] == t) { hit = w; break; }
			if (hit == ways) {
				misses++;
				unsigned victim = 0;
				for (unsigned w = 0; w < ways; w++) if (tg[w] == 0xFFFFFFFFu) { victim = w; break; }
				if (tg[victim] != 0xFFFFFFFFu)
					for (unsigned w = 0; w < ways; w++) if (ag[w] > ag[victim]) victim = w;
				tg[victim] = t; hit = victim;
			}
			for (unsigned w = 0; w < ways; w++) if (ag[w] < ag[hit]) ag[w]++;
			ag[hit] = 0;
		}
	};

	Prof040() { reset(); }

	void reset() {
		cycles = 0; retire_total = 0;
		memset(retire_hist, 0, sizeof retire_hist);
		memset(busy, 0, sizeof busy); memset(busy_retire, 0, sizeof busy_retire);
		memset(stall, 0, sizeof stall);
		memset(xact_n, 0, sizeof xact_n); memset(xact_cyc, 0, sizeof xact_cyc); memset(xact_max, 0, sizeof xact_max);
		for (auto& m : lat) m.clear();
		xfer_active = false; xfer_start = 0; xfer_class = 0;
		prev_retire_n = 0; cyc_acc = 0;
		memset(rom_cyc, 0, sizeof rom_cyc); memset(rom_ret, 0, sizeof rom_ret);
		ram_pc.clear();
		rom_lines_touched.assign(65536 / 64, 0); rom_line_refs = 0;
		static const struct { const char* n; unsigned b, w; } cfg[] = {
			{"dm_64k", 65536, 1}, {"dm_128k", 131072, 1}, {"dm_256k", 262144, 1}, {"dm_512k", 524288, 1},
			{"2way_128k", 131072, 2}, {"2way_256k", 262144, 2}, {"4way_64k", 65536, 4}, {"full_1m", 1048576, 1}};
		rom_caches.resize(8);
		for (int i = 0; i < 8; i++) rom_caches[i].init(cfg[i].n, cfg[i].b, cfg[i].w);
		memset(vram_w_size, 0, sizeof vram_w_size); vram_w_span = vram_w_unaligned = 0;
		vram_w_n = vram_r_n = vram_r_hit = vram_r_line = vram_wp_beats = 0;
		memset(vram_r_size, 0, sizeof vram_r_size);
		vram_w_prev64 = 0xFFFFFFFFu; vram_w_prev_cycle = 0; vram_r_prev_cycle = 0;
		memset(vram_w_delta, 0, sizeof vram_w_delta); memset(vram_w_gap, 0, sizeof vram_w_gap); memset(vram_r_gap, 0, sizeof vram_r_gap);
		for (int w = 0; w < 4; w++) { rdc_tag[w] = 0xFFFFFFFFu; }
		rdc_victim = 0;
		vram_rmw = 0; last_vram_w64 = 0xFFFFFFFFu;
		m_vram_w_n = 0; m_vram_w_cyc = 0; m_xfer = false; m_start = 0;
		windows.clear(); win_cur = Window(); win_idx = 0;
	}

	void open_trace(const char* path) { trace = fopen(path, "wb"); }

	void step(const Prof040Sample& s) {
		cycles++;
		const int rn = (s.retire ? 1 : 0) + (s.retire2 ? 1 : 0);
		retire_hist[rn]++; retire_total += rn;
		win_cur.retires += rn;

		// PC attribution: the stall before an instruction retires is charged
		// to that instruction (retired_pc is valid the clock after the strobe).
		if (prev_retire_n) {
			charge(s.retired_pc, cyc_acc, prev_retire_n);
			cyc_acc = 0;
		}
		cyc_acc++;
		prev_retire_n = rn;

		// core-side transfer tracking
		if (s.c_req && !xfer_active) {
			xfer_active = true; xfer_start = cycles;
			const int r = region_of(s.c_addr);
			const int k = s.c_instr ? K_IF : (s.c_write ? K_DW : K_DR);
			xfer_class = k * R_N + r;
			xfer_addr = s.c_addr; xfer_size = s.c_size; xfer_line = s.c_line;
			on_xact_start(k, r, s);
		}
		if (xfer_active) {
			busy[xfer_class]++; busy_retire[xfer_class] += rn;
			if (s.c_req && s.c_ack && s.c_last) {
				const uint64_t d = cycles - xfer_start + 1;
				xact_n[xfer_class]++; xact_cyc[xfer_class] += d;
				if (d > xact_max[xfer_class]) xact_max[xfer_class] = d;
				lat[xfer_class][d > 256 ? 256 : (uint32_t)d]++;
				xfer_active = false;
			}
		}
		// platform-side VRAM write occupancy (after the store buffer)
		if (s.m_req && !m_xfer) { m_xfer = true; m_start = cycles; m_vram = s.m_write && region_of(s.m_addr) == R_VRAM; }
		if (m_xfer) {
			if (m_vram) m_vram_w_cyc++;
			if (s.m_ack || !s.m_req) { if (m_vram) m_vram_w_n++; m_xfer = false; }
		}
		if (s.vram_wp) { vram_wp_beats++; win_cur.vram_beats++; }

		// zero-retire cycles by heuristic reason
		if (rn == 0) {
			int st;
			if (xfer_active) {
				const int k = xfer_class / R_N, r = xfer_class % R_N;
				if (k == K_IF) st = r == R_ROM ? ST_IF_ROM : r == R_RAM ? ST_IF_RAM : ST_IF_OTHER;
				else if (k == K_DR) st = r == R_VRAM ? ST_DR_VRAM : r == R_RAM ? ST_DR_RAM : r == R_ROM ? ST_DR_ROM : ST_DR_OTHER;
				else st = r == R_VRAM ? ST_DW_VRAM : r == R_RAM ? ST_DW_RAM : ST_DW_OTHER;
			}
			else if (s.dmu_busy) st = ST_DMU_NOBUS;
			else if (s.sb_pending) st = ST_SB_NOBUS;
			else if (s.qcnt == 0) st = ST_FETCH_STARVED;
			else st = ST_INTERNAL;
			stall[st]++; win_cur.stall[st]++;
		}

		if ((cycles & ((1u << 20) - 1)) == 0) { windows.push_back(win_cur); win_cur = Window(); win_idx++; }
	}

	// read_long(addr): big-endian long from guest RAM; dis(pc, &len): one disassembled line
	void dump(const char* path, const char* traps_path,
	          uint32_t (*read_long)(uint32_t), const char* (*dis)(uint32_t, unsigned*)) {
		if (trace) { fclose(trace); trace = nullptr; }
		FILE* f = fopen(path, "w");
		if (!f) { fprintf(stderr, "[CPU-PROFILE] cannot write %s\n", path); return; }
		const double ipc = cycles ? (double)retire_total / cycles : 0.0;
		fprintf(f, "SUMMARY\tcycles\t%llu\n", (unsigned long long)cycles);
		fprintf(f, "SUMMARY\tretirements\t%llu\n", (unsigned long long)retire_total);
		fprintf(f, "SUMMARY\tipc\t%.4f\n", ipc);
		fprintf(f, "SUMMARY\tcpi\t%.4f\n", retire_total ? (double)cycles / retire_total : 0.0);
		fprintf(f, "SUMMARY\tnote\tstall reasons are heuristics from sampled state; transactions are the core's own bus (before the store buffer)\n");
		for (int i = 0; i < 3; i++)
			fprintf(f, "RETIRE\t%d_per_cycle\t%llu\t%.2f%%\n", i, (unsigned long long)retire_hist[i], pct(retire_hist[i], cycles));
		fprintf(f, "BUSY\tclass\tcycles\tpct_of_cycles\tretires_under\n");
		uint64_t busy_total = 0;
		for (int c = 0; c < NCLASS; c++) if (busy[c]) {
			busy_total += busy[c];
			fprintf(f, "BUSY\t%s_%s\t%llu\t%.2f%%\t%llu\n", kind_name(c / R_N), region_name(c % R_N),
			        (unsigned long long)busy[c], pct(busy[c], cycles), (unsigned long long)busy_retire[c]);
		}
		fprintf(f, "BUSY\tany_transfer\t%llu\t%.2f%%\n", (unsigned long long)busy_total, pct(busy_total, cycles));
		fprintf(f, "STALL\treason\tcycles\tpct_of_cycles\n");
		uint64_t stall_total = 0;
		for (int s = 0; s < ST_N; s++) { stall_total += stall[s];
			if (stall[s]) fprintf(f, "STALL\t%s\t%llu\t%.2f%%\n", stall_name(s), (unsigned long long)stall[s], pct(stall[s], cycles)); }
		fprintf(f, "STALL\ttotal_zero_retire\t%llu\t%.2f%%\n", (unsigned long long)stall_total, pct(stall_total, cycles));
		fprintf(f, "XACT\tclass\tcount\tcycles\tmean_latency\tmax_latency\tper_1000_retire\n");
		for (int c = 0; c < NCLASS; c++) if (xact_n[c])
			fprintf(f, "XACT\t%s_%s\t%llu\t%llu\t%.2f\t%llu\t%.2f\n", kind_name(c / R_N), region_name(c % R_N),
			        (unsigned long long)xact_n[c], (unsigned long long)xact_cyc[c],
			        (double)xact_cyc[c] / xact_n[c], (unsigned long long)xact_max[c],
			        retire_total ? 1000.0 * xact_n[c] / retire_total : 0.0);
		fprintf(f, "XACT\tplatform_vram_write\t%llu\t%llu\t%.2f\n", (unsigned long long)m_vram_w_n,
		        (unsigned long long)m_vram_w_cyc, m_vram_w_n ? (double)m_vram_w_cyc / m_vram_w_n : 0.0);
		fprintf(f, "LAT\tclass\tlatency\tcount\n");
		for (int c = 0; c < NCLASS; c++) for (auto& kv : lat[c])
			fprintf(f, "LAT\t%s_%s\t%u\t%llu\n", kind_name(c / R_N), region_name(c % R_N), kv.first, (unsigned long long)kv.second);

		uint64_t touched = 0;
		for (uint64_t w : rom_lines_touched) touched += __builtin_popcountll(w);
		fprintf(f, "ROMCACHE\tline_refs\t%llu\n", (unsigned long long)rom_line_refs);
		fprintf(f, "ROMCACHE\tdistinct_lines\t%llu\t%.1f_KB\n", (unsigned long long)touched, touched * 16.0 / 1024.0);
		fprintf(f, "ROMCACHE\tcache\trefs\tmisses\tmiss_pct\tmisses_per_1000_retire\n");
		for (auto& c : rom_caches)
			fprintf(f, "ROMCACHE\t%s\t%llu\t%llu\t%.3f%%\t%.2f\n", c.name.c_str(), (unsigned long long)c.refs,
			        (unsigned long long)c.misses, pct(c.misses, c.refs), retire_total ? 1000.0 * c.misses / retire_total : 0.0);

		fprintf(f, "VRAM\tstores\t%llu\n", (unsigned long long)vram_w_n);
		fprintf(f, "VRAM\tstore_beats_platform\t%llu\n", (unsigned long long)vram_wp_beats);
		static const char* szn[4] = {"byte", "word", "long", "line"};
		for (int i = 0; i < 4; i++) fprintf(f, "VRAM\tstore_%s\t%llu\n", szn[i], (unsigned long long)vram_w_size[i]);
		fprintf(f, "VRAM\tstore_unaligned_in_long\t%llu\n", (unsigned long long)vram_w_unaligned);
		fprintf(f, "VRAM\tstore_spanning_two_longs\t%llu\n", (unsigned long long)vram_w_span);
		fprintf(f, "VRAM\tstore_delta64\tsame\t%llu\n", (unsigned long long)vram_w_delta[0]);
		fprintf(f, "VRAM\tstore_delta64\tplus1\t%llu\n", (unsigned long long)vram_w_delta[1]);
		fprintf(f, "VRAM\tstore_delta64\tminus1\t%llu\n", (unsigned long long)vram_w_delta[2]);
		fprintf(f, "VRAM\tstore_delta64\tplus_row_1024\t%llu\n", (unsigned long long)vram_w_delta[3]);
		fprintf(f, "VRAM\tstore_delta64\tother\t%llu\n", (unsigned long long)vram_w_delta[4]);
		fprintf(f, "VRAM\tstore_gap_log2\tbucket\tcount\n");
		for (int i = 0; i < 16; i++) if (vram_w_gap[i]) fprintf(f, "VRAM\tstore_gap_log2\t%d\t%llu\n", i, (unsigned long long)vram_w_gap[i]);
		fprintf(f, "VRAM\treads\t%llu\n", (unsigned long long)vram_r_n);
		for (int i = 0; i < 4; i++) fprintf(f, "VRAM\tread_%s\t%llu\n", szn[i], (unsigned long long)vram_r_size[i]);
		fprintf(f, "VRAM\tread_hits_4way32B_model\t%llu\t%.2f%%\n", (unsigned long long)vram_r_hit, pct(vram_r_hit, vram_r_n));
		fprintf(f, "VRAM\tread_after_store_same_long\t%llu\n", (unsigned long long)vram_rmw);
		fprintf(f, "VRAM\tread_gap_log2\tbucket\tcount\n");
		for (int i = 0; i < 16; i++) if (vram_r_gap[i]) fprintf(f, "VRAM\tread_gap_log2\t%d\t%llu\n", i, (unsigned long long)vram_r_gap[i]);

		fprintf(f, "WINDOW\tidx\tretires\tvram_beats\tstall_if_rom\tstall_dr_vram\tstall_dw_vram\tstall_dr_ram\tstall_if_ram\tstall_dmu\tstall_internal\n");
		std::vector<Window> ws = windows; ws.push_back(win_cur);
		for (size_t i = 0; i < ws.size(); i++)
			fprintf(f, "WINDOW\t%zu\t%llu\t%llu\t%llu\t%llu\t%llu\t%llu\t%llu\t%llu\t%llu\n", i,
			        (unsigned long long)ws[i].retires, (unsigned long long)ws[i].vram_beats,
			        (unsigned long long)ws[i].stall[ST_IF_ROM], (unsigned long long)ws[i].stall[ST_DR_VRAM],
			        (unsigned long long)ws[i].stall[ST_DW_VRAM], (unsigned long long)ws[i].stall[ST_DR_RAM],
			        (unsigned long long)ws[i].stall[ST_IF_RAM], (unsigned long long)ws[i].stall[ST_DMU_NOBUS],
			        (unsigned long long)ws[i].stall[ST_INTERNAL]);

		// trap attribution: nearest preceding trap entry (OS table $400, Toolbox $E00)
		std::map<uint32_t, std::string> entries;
		{
			std::map<unsigned, std::string> names;
			if (traps_path) if (FILE* t = fopen(traps_path, "r")) {
				char line[128];
				while (fgets(line, sizeof line, t)) {
					unsigned num; char nm[96];
					if (sscanf(line, "%x %95s", &num, nm) == 2) names[num] = nm;
				}
				fclose(t);
			}
			if (read_long) {
				for (unsigned i = 0; i < 256; i++) {
					const uint32_t e = read_long(0x400 + 4 * i);
					if (e) entries[e] = trap_name(names, 0xA000 + i);
				}
				for (unsigned i = 0; i < 1024; i++) {
					const uint32_t e = read_long(0xE00 + 4 * i);
					if (e) entries[e] = trap_name(names, 0xA800 + i);
				}
			}
		}
		struct Agg { uint64_t cyc = 0, ret = 0; };
		std::map<std::string, Agg> by_trap;
		std::vector<std::pair<uint64_t, uint32_t>> hot;   // cycles, pc bucket
		for (uint32_t b = 0; b < 65536; b++) if (rom_cyc[b]) {
			const uint32_t pc = 0x40800000u | (b << 4);
			Agg& a = by_trap[attribute(entries, pc)];
			a.cyc += rom_cyc[b]; a.ret += rom_ret[b];
			hot.push_back({rom_cyc[b], pc});
		}
		for (auto& kv : ram_pc) {
			const uint32_t pc = kv.first << 4;
			Agg& a = by_trap[attribute(entries, pc)];
			a.cyc += kv.second.cyc; a.ret += kv.second.ret;
			hot.push_back({kv.second.cyc, pc});
		}
		std::vector<std::pair<std::string, Agg>> tv(by_trap.begin(), by_trap.end());
		std::sort(tv.begin(), tv.end(), [](const std::pair<std::string, Agg>& a, const std::pair<std::string, Agg>& b) { return a.second.cyc > b.second.cyc; });
		fprintf(f, "TRAP\tname\tcycles\tpct\tretires\tcpi\n");
		for (size_t i = 0; i < tv.size() && i < 60; i++)
			fprintf(f, "TRAP\t%s\t%llu\t%.2f%%\t%llu\t%.2f\n", tv[i].first.c_str(), (unsigned long long)tv[i].second.cyc,
			        pct(tv[i].second.cyc, cycles), (unsigned long long)tv[i].second.ret,
			        tv[i].second.ret ? (double)tv[i].second.cyc / tv[i].second.ret : 0.0);
		std::sort(hot.begin(), hot.end(), [](const std::pair<uint64_t, uint32_t>& a, const std::pair<uint64_t, uint32_t>& b) { return a.first > b.first; });
		fprintf(f, "HOT\tpc_bucket\tcycles\tpct\tretires\tcpi\tattribution\n");
		for (size_t i = 0; i < hot.size() && i < 48; i++) {
			const uint32_t pc = hot[i].second;
			const uint64_t ret = (pc >> 28) == 4 ? rom_ret[(pc & 0xFFFFF) >> 4] : ram_pc[pc >> 4].ret;
			fprintf(f, "HOT\t%08X\t%llu\t%.2f%%\t%llu\t%.2f\t%s\n", pc, (unsigned long long)hot[i].first,
			        pct(hot[i].first, cycles), (unsigned long long)ret, ret ? (double)hot[i].first / ret : 0.0,
			        attribute(entries, pc).c_str());
			if (dis && i < 24) {
				uint32_t p = pc;
				for (int n = 0; n < 8 && p < pc + 16; n++) {
					unsigned len = 2;
					const char* d = dis(p, &len);
					fprintf(f, "DIS\t%08X\t%s\n", p, d ? d : "?");
					if (!len) break;
					p += len;
				}
			}
		}
		fclose(f);
		printf("[CPU-PROFILE] wrote %s: %llu cycles, %llu retirements, IPC %.3f\n", path,
		       (unsigned long long)cycles, (unsigned long long)retire_total, ipc);
		fflush(stdout);
	}

private:
	struct Window { uint64_t retires = 0, vram_beats = 0; uint64_t stall[ST_N] = {}; };
	struct PcAgg { uint64_t cyc = 0, ret = 0; };

	static double pct(uint64_t a, uint64_t b) { return b ? 100.0 * a / b : 0.0; }
	static std::string trap_name(const std::map<unsigned, std::string>& names, unsigned num) {
		auto it = names.find(num);
		char buf[32];
		if (it != names.end()) return it->second;
		snprintf(buf, sizeof buf, "trap_%04X", num);
		return buf;
	}
	static std::string attribute(const std::map<uint32_t, std::string>& entries, uint32_t pc) {
		auto it = entries.upper_bound(pc);
		const bool rom = (pc >> 28) == 4;
		if (it != entries.begin()) {
			--it;
			const uint32_t dist = pc - it->first;
			if (dist < (rom ? 0x10000u : 0x4000u)) return it->second;
		}
		char buf[40];
		snprintf(buf, sizeof buf, rom ? "rom_%05X_unattributed" : "ram_%08X_unattributed",
		         rom ? (pc & 0xFFFFF) & ~0xFFFu : pc & ~0xFFFu);
		return buf;
	}
	void charge(uint32_t pc, uint64_t cyc, int n) {
		if ((pc >> 28) == 4) { const uint32_t b = (pc & 0xFFFFF) >> 4; rom_cyc[b] += cyc; rom_ret[b] += n; }
		else { PcAgg& a = ram_pc[pc >> 4]; a.cyc += cyc; a.ret += n; }
	}
	static int log2bucket(uint64_t v) { int b = 0; while (v > 1 && b < 15) { v >>= 1; b++; } return b; }

	void on_xact_start(int k, int r, const Prof040Sample& s) {
		if (trace) {
			struct { uint64_t cyc; uint32_t addr; uint8_t kind, size, region, line; } rec =
				{cycles, s.c_addr, (uint8_t)k, s.c_size, (uint8_t)r, (uint8_t)s.c_line};
			fwrite(&rec, sizeof rec, 1, trace);
		}
		if (r == R_ROM && k != K_DW) {
			const uint32_t line = (s.c_addr & 0xFFFFF) >> 4;
			rom_line_refs++;
			rom_lines_touched[line >> 6] |= 1ull << (line & 63);
			for (auto& c : rom_caches) c.access(line);
		}
		if (r == R_VRAM) {
			const uint32_t a = s.c_addr & 0x1FFFFF;
			const uint32_t w64 = a >> 3, line32 = a >> 5;
			const unsigned bytes = s.c_line ? 16 : (s.c_size == 0 ? 1 : s.c_size == 1 ? 2 : 4);
			const int szi = s.c_line ? 3 : s.c_size;
			if (k == K_DW) {
				vram_w_n++; vram_w_size[szi]++;
				if (!s.c_line && (a & 3)) vram_w_unaligned++;
				if (!s.c_line && (a & 3) + bytes > 4) vram_w_span++;
				if (vram_w_prev64 != 0xFFFFFFFFu) {
					const int32_t d = (int32_t)(w64 - vram_w_prev64);
					vram_w_delta[d == 0 ? 0 : d == 1 ? 1 : d == -1 ? 2 : d == 128 ? 3 : 4]++;
					vram_w_gap[log2bucket(cycles - vram_w_prev_cycle)]++;
				}
				vram_w_prev64 = w64; vram_w_prev_cycle = cycles;
				last_vram_w64 = a >> 2;
				for (int w = 0; w < 4; w++) if (rdc_tag[w] == line32) rdc_tag[w] = 0xFFFFFFFFu;   // conservative: write drops the line
			}
			else if (k == K_DR) {
				vram_r_n++; vram_r_size[szi]++;
				if ((a >> 2) == last_vram_w64) vram_rmw++;
				if (vram_r_prev_cycle) vram_r_gap[log2bucket(cycles - vram_r_prev_cycle)]++;
				vram_r_prev_cycle = cycles;
				bool hit = false;
				for (int w = 0; w < 4; w++) if (rdc_tag[w] == line32) { hit = true; break; }
				if (hit) vram_r_hit++;
				else { rdc_tag[rdc_victim] = line32; rdc_victim = (rdc_victim + 1) & 3; }
			}
		}
	}

	uint64_t cycles, retire_total, retire_hist[3];
	uint64_t busy[NCLASS], busy_retire[NCLASS], stall[ST_N];
	uint64_t xact_n[NCLASS], xact_cyc[NCLASS], xact_max[NCLASS];
	std::map<uint32_t, uint64_t> lat[NCLASS];
	bool xfer_active; uint64_t xfer_start; int xfer_class; uint32_t xfer_addr; uint8_t xfer_size; bool xfer_line;
	int prev_retire_n; uint64_t cyc_acc;
	uint64_t rom_cyc[65536], rom_ret[65536];
	std::unordered_map<uint32_t, PcAgg> ram_pc;
	std::vector<uint64_t> rom_lines_touched; uint64_t rom_line_refs;
	std::vector<CacheSim> rom_caches;
	uint64_t vram_w_size[4], vram_w_span, vram_w_unaligned, vram_w_n, vram_r_n, vram_r_hit, vram_r_line, vram_wp_beats;
	uint64_t vram_r_size[4];
	uint32_t vram_w_prev64; uint64_t vram_w_prev_cycle, vram_r_prev_cycle;
	uint64_t vram_w_delta[5], vram_w_gap[16], vram_r_gap[16];
	uint32_t rdc_tag[4]; int rdc_victim;
	uint64_t vram_rmw; uint32_t last_vram_w64;
	uint64_t m_vram_w_n, m_vram_w_cyc; bool m_xfer, m_vram; uint64_t m_start;
	std::vector<Window> windows; Window win_cur; uint64_t win_idx;
	FILE* trace = nullptr;
};

#endif
