export BASE=$PWD
export GEM5DIR=$BASE/gem5-custom

#export NPROC=$(grep -c processor /proc/cpuinfo)

#Pass the release name
export OS_RELEASE_NAME=$1
export KERN_SRC=$BASE/linux-4.17
#CPU parallelism
export CORES="32"
export VER="4.17.0"
#export VER="4.18.0-2-amd64"

#QEMU
export QEMU_IMG=$BASE
export QEMU_IMG_FILE=$QEMU_IMG/iceberg.img
export MOUNT_DIR=$QEMU_IMG/mountdir
export QEMUMEM="50G"
export QEMUNODE1="25G"
export QEMUNODE2="25G"


export KERNEL=$BASE/KERNEL

#BENCHMARKS AND LIBS
export LINUX_SCALE_BENCH=$BASE/linux-scalability-benchmark
export APPBENCH=$BASE/appbench
export SHARED_LIBS=$APPBENCH/shared_libs
export QUARTZ=$SHARED_LIBS/quartz

#SCRIPTS
export SCRIPTS=$BASE/scripts
export INPUTXML=$SCRIPTS/input.xml
export QUARTZSCRIPTS=$SHARED_LIBS/quartz/scripts
export SHARED_DATA=$APPBENCH/shared_data

export APPPREFIX="numactl --preferred=0 /usr/bin/time -v"
#export OUTPUTDIR=$BASE/results/INODELRU
#export OUTPUTDIR=$BASE/results/CAMERA/MEMUSE
export TEST_TMPDIR=/mnt/pmemdir
#ln -s /usr/bin/ccache /usr/local/bin/gcc
# ccache for Linux development
export CC="gcc"
export CXX="g++"
# Set cache size




#Commands
mkdir $OUTPUTDIR
mkdir $KERNEL
