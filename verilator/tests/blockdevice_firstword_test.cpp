// Actual SimBlockDevice producer connected to actual scsi_cache RTL.
// No CPU, NCR, disk image, GUI or simulated OS is needed to expose this edge.
#include "Vscsi_cache.h"
#include "sim_blkdevice.h"
#include <array>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>

// The producer never calls GUI logging; isolate only that unused dependency.
DebugConsole::DebugConsole() {}
DebugConsole::~DebugConsole() {}
static DebugConsole debug;
static SimBlockDevice device(debug); // same static zero-init as sim_main
static Vscsi_cache top;
static CData readonly_pin=0;
static IData unused_lba=0;
static SData unused_din=0;
static uint64_t ticks=0;
static unsigned failures=0,checks=0,ack_edges=0;
static CData previous_ack=0;
static std::array<uint16_t,256> received;

static uint16_t pattern(unsigned sector,unsigned word) {
 return word==0 ? uint16_t(0x4552+sector) : uint16_t(0xA000+sector*257+word);
}
static void tick() {
 top.clk=0;top.eval();
 device.BeforeEval(2002+ticks*2);
 if((top.p_ack & 1) && !(previous_ack & 1)) {
  ++ack_edges;
  std::printf("PRODUCER_ACK tick=%llu lba=%u first_wr=%u addr=%u data=%04x blocks=%u\n",
   (unsigned long long)ticks,top.p_lba,top.p_buff_wr,top.p_buff_addr,top.p_buff_dout,top.p_blk_cnt+1);
 }
 previous_ack=top.p_ack;
 top.clk=1;top.eval();device.AfterEval();
 if(top.e_buff_wr) received.at(top.e_buff_addr)=top.e_buff_dout;
 if(++ticks>300000) {std::fprintf(stderr,"TIMEOUT\n");std::exit(2);}
}
static void read_sector(unsigned sector) {
 received.fill(0xDEAD);
 top.e_lba=sector;top.e_rd=1;
 while(!(top.e_ack&1)) tick();
 top.e_rd=0;
 while(top.e_ack&1) tick();
 tick();
 for(unsigned word=0;word<256;++word) {
  ++checks;
  if(received[word]!=pattern(sector,word)) {
   ++failures;
   if(failures<12) std::printf("MISMATCH sector=%u word=%u got=%04x expected=%04x\n",
     sector,word,received[word],pattern(sector,word));
  }
 }
 std::printf("READ sector=%u word0=%04x word1=%04x checks=%u failures=%u\n",
  sector,received[0],received[1],checks,failures);
}
int main(int argc,char**argv) {
 Verilated::commandArgs(argc,argv);
 const char*path=std::getenv("FIRSTWORD_IMAGE");
 if(!path) {std::fprintf(stderr,"FIRSTWORD_IMAGE required\n");return 2;}
 {
  std::ofstream image(path,std::ios::binary|std::ios::trunc);
  for(unsigned sector=0;sector<128;++sector)
   for(unsigned word=0;word<256;++word) {
    uint16_t value=pattern(sector,word);image.put(value>>8);image.put(value&255);
   }
  if(!image) return 2;
 }
 device.sd_lba[0]=&top.p_lba;device.sd_blk_cnt=&top.p_blk_cnt;
 device.sd_rd=&top.p_rd;device.sd_wr=&top.p_wr;device.sd_ack=&top.p_ack;
 device.sd_buff_addr=&top.p_buff_addr;device.sd_buff_dout=&top.p_buff_dout;
 device.sd_buff_din[0]=&top.p_buff_din;device.sd_buff_wr=&top.p_buff_wr;
 device.img_mounted=&top.img_mounted;device.img_readonly=&readonly_pin;
 device.img_size=&top.img_size;
 for(unsigned slot=1;slot<kVDNUM;++slot) {
  device.sd_lba[slot]=&unused_lba;device.sd_buff_din[slot]=&unused_din;
 }
 top.nreset=0;top.e_lba=0;top.e_rd=0;top.e_wr=0;top.e_buff_din=0;
 for(int i=0;i<4;++i) tick();top.nreset=1;
 device.MountDisk(path,0);
 for(int i=0;i<5000;++i) tick();
 read_sector(0); // cold: first word of the first eight-sector platform transfer
 read_sector(0); // same cache hit must preserve its first word
 read_sector(1); // later sector in that transfer checks no two-byte shift
 read_sector(80); // fresh rebased window, a second first-word opportunity
 std::printf("FIRSTWORD_RESULT checks=%u failures=%u platform_ack_edges=%u ticks=%llu\n",
  checks,failures,ack_edges,(unsigned long long)ticks);
 top.final();return failures ? 1 : 0;
}
