#pragma once
#include <iostream>
#include <fstream>
#include "verilated.h"
#include "sim_console.h"


#ifndef _MSC_VER
#else
#define WIN32
#endif

#define kVDNUM 10
#define kBLKSZ 512

struct SimBlockDevice {
public:

	IData* sd_lba[kVDNUM];
	CData* sd_blk_cnt;      // additional 512-byte blocks in this transfer
	CData* sd_rd;           // 2-bit in MacLC
	CData* sd_wr;           // 2-bit in MacLC
	CData* sd_ack;          // 2-bit in MacLC
	SData* sd_buff_addr;    // 13-bit word address for up to 32 blocks
	SData* sd_buff_dout;    // 16-bit for MacLC
	SData* sd_buff_din[kVDNUM];  // 16-bit for MacLC
	CData* sd_buff_wr;
	CData* img_mounted;     // 2-bit in MacLC
	CData* img_readonly;
	QData* img_size;

	int bytecnt;
	int transfer_bytes;
        long int disk_size[kVDNUM];
	bool reading;
	bool writing;
	int ack_delay;
	int current_disk;
	bool mountQueue[kVDNUM];
	std::fstream disk[kVDNUM];

	// cycles is the sim's half-cycle counter: must be 64-bit — an int
	// wraps negative at 2^31 (~1.07G machine cycles) and the <2000 boot
	// guard then disables the block device forever, mid-transfer
	void BeforeEval(long long cycles);
	void AfterEval(void);
	//void QueueDownload(std::string file, int index);
	//void QueueDownload(std::string file, int index, bool restart);
	//bool HasQueue();
	void MountDisk( std::string file, int index);

	SimBlockDevice(DebugConsole c);
	~SimBlockDevice();


private:
	//std::queue<SimBus_DownloadChunk> downloadQueue;
	//SimBus_DownloadChunk currentDownload;
	//void SetDownload(std::string file, int index);
};
