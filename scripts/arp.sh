#!/bin/bash

set -x

sbatch -N1 -p ndl       cy49/arp/arp.sh NVHPC2303 xs t0031
sbatch -N1 -p ndl       cy49/arp/arp.sh NVHPC2303 xd t0031

sbatch -N3 -p ndl       cy49/arp/arp.sh NVHPC2303 xs t0798
sbatch -N3 -p ndl       cy49/arp/arp.sh NVHPC2303 xd t0798

sbatch -N1 -p normal256 cy49/arp/arp.sh NVHPC2303 xs t0031
sbatch -N1 -p normal256 cy49/arp/arp.sh NVHPC2303 xd t0031

sbatch -N3 -p normal256 cy49/arp/arp.sh INTEL1805 xd t0798
sbatch -N3 -p normal256 cy49/arp/arp.sh INTEL1805 xs t0798


