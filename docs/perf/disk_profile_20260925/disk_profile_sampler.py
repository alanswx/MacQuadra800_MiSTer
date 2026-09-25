import os
import time

pid = os.popen('pidof MiSTer').read().split()[0]
for _ in range(90):
    stamp = time.time()
    io = {}
    with open('/proc/' + pid + '/io') as f:
        for line in f:
            key, value = line.split(':')
            io[key] = int(value)
    with open('/proc/' + pid + '/stat') as f:
        stat = f.read().split()
    with open('/proc/diskstats') as f:
        device = next(line.split() for line in f if line.split()[2] == 'mmcblk0')
    print('%.3f' % stamp,
          io['rchar'], io['wchar'], io['syscr'], io['syscw'],
          io['read_bytes'], io['write_bytes'],
          stat[13], stat[14], stat[21], *device[3:13], flush=True)
    time.sleep(1)
