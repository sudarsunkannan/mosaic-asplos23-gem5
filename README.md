
## System Requirements
---------------------
- A Linux system (possibly Debian distribution)
- 4 or more cores
- At least 20GB of free RAM


## 1. Setting  Gem5 Mosaic on CloudLab
--------------------------------------
You have the option to run Gem5 Mosaic on CloudLab (which we used for
development and experiments). If you do not want to use CloudLab, skip to 2.

## 1.1 Instantiating CloudLab nodes before cloning the repo 
We run the gem5 simulation in CloubLab and use its fast NVMe storage to speed up full system simulation. We recommend users use the following profile to instantiate two CloudLab nodes.

CloudLab profile: 2-NVMe-Nodes

Instantiating this profile will launch NVMe-based nodes, where one could run multiple instances.

We currently support Ubuntu-based 18.04 kernels, and all package installation scripts use Debian.

## 1.2 Partitioning an SSD and downloading the code.
If you are using Mosaic gem5 in CloudLab, the root partition is only 16GB for
some profiles. First, set up the CloudLab node with SSD and download the code
on the SSD folder.

If you are using the 2-NVMe-Nodes profile, then the NVMe SSD with 256GB is in
"/dev/nvme0n1p4"

### 1.3 To partition an ext4 file system, use the following commands
```
sudo mkfs.ext4 /dev/nvme0n1p4 
mkdir ~/ssd
sudo mount /dev/nvme0n1p4  ~/ssd
sudo chown -R $USER ~/ssd
cd ~/ssd
```

### 1.4 Now clone the repo


## 2. Compilation
------------------------

### 2.1 Setting the environmental variables
MAKE SURE to set the correct OS release by assigning the correct
OS_RELEASE_NAME. In Debian distributions, this can be extracted using "lsb_release -a"
```
export OS_RELEASE_NAME="bionic"
source scripts/setvars.sh $OS_RELEASE_NAME
```

### 2.2 Compile gem5 and linux 4.17 kernel. 

Feel free to use other kernel versions if required.

```
./compile.sh
```
## 2.2 QEMU image setup for gem5 full system simulation
By default, the script creates a QEMU image size of 16GB. If you 
would like a larger image, in the image creation script added 
below (create_qemu_img.sh), change the following line as needed. 
```
qemu-img create $QEMU_IMG_FILE 16g
```
```
./create_qemu_img.sh
```

### 2.3 Mount the QEMU image
A successful mount followed by "df" command will show the mounted 
directory. Some VMs might not have /bin/tcsh. So, we will manually 
copy to the VM disk file.
```
test-scripts/mount_qemu.sh
```
### 2.4 Copying applications and gem5 scripts to VM
To copy all apps to the root folder inside the QEMU image, use the following
command. In addition to the application, we also copy the m5 application
required for letting the gem5 host for starting and stoping the simulation.
```
$BASE/test-scripts/copyapps_qemu.sh
(or)
sudo cp -r apps/* $BASE/mountdir/
```
### 2.5 Setting the password for QEMU VM
Set the username for the VM to root and the password to the letter "s". This is
just a QEMU gem5 VM and will not cause any issues. *We will make them
configurable soon to avoid using a specific password.*

```
cd $BASE/mountdir
sudo chroot .
passwd
```
Once the password is set, exit the VM and umount the image

```
exit
cd $BASE
test-scripts/umount_qemu.sh
```
### 2.6 Disabling paranoid mode
```
echo "-1" | sudo tee /proc/sys/kernel/perf_event_paranoid
```

## 3 Running Simulations
----------------------
We use "test-scripts/run.sh," a reasonably automated script to run the
simulations for different applications.

### 3.1 Setting the application to run
To set, which applications to run, in the test-scripts/run.sh script, 
set the **WORKLOAD_NAME** parameter. 

In the AE, as evaluated in the paper, we have included the sample applications: 
(1) hello, (2) graph500, (3) XSbench, (4) btree, or (5) gups

For example,
```
WORKLOAD_NAME=hello
or
WORKLOAD_NAME=graph500
or
WORKLOAD_NAME=xsbench
or
WORKLOAD_NAME=btree
or
WORKLOAD_NAME=gups
```
### 3.2 Setting associativity number
Mosaic and vanilla TLB designs can be run with different associativity using a list.

To run with just one TLB associativity, set the "waylist" with just one value.
```
vim test-scripts/run.sh
waylist=(2)
```
For running with different associativity 
```
waylist=(2 4 8 "full")

```
### 3.3 Setting Mosaic's TOC size
Similar to associativity, for Mosaic, we could also vary the TOC size in run.sh
```
toclist=(4)
or
toclist=(4 8 16 32 64)
```

### 3.4 Running gem5 simulator
```
test-scripts/run.sh
```

### 3.5 Optional: Setting the  port
To run an application inside a VM and begin the simulation, we need to login to
the QEMU VM, run gem5's *m5 exit* inside the VM, followed by running an
application (also inside the VM), and finally run *m5 exit* to signal the gem5
simulator in the host that an application has finished execution and it is time
to stop the simulation.

To avoid manually logging into a VM and running an application, we use telnet
and a specific PORT number. If you don't want to use the default PORT number,
set the PORT in test-scripts/run.sh
```
#Intializing TCP_PORT
TCP_PORT=3460
```

### 3.6 Optional: Setting application parameter
For each application, we use a separate python script to input application
parameters and run telnet. Once the *WORKLOAD_NAME* parameter is set, the
script automatically chooses the application script using the workload name.
Only if one would like to modify the application input, the following python
scripts need to be changed.
```
gem5_client_hello.py
gem5_client_gups.py
```

## 4. Result Generation
-------------------

In full system simulation, for each memory reference, we use a Vanilla TLB and
a parallel Iceberg TLB to collect the TLB miss rate for both Vanilla and
Mosaic.

After an application has finished running for a configuration, the miss rates
are printed as shown below.

```
Sample output:

Vanilla TLB miss rate:1.1046%
Mosaic TLB miss rate:0.7307%
```
## 4.1 Result Files
The result files can be seen in the result folder inside the base gem5-linux
($BASE) folder. The result file path is of the following structure:
```
result/$APP/iceberg/$ASSOCIATIVTY/$TOCSIZE
e.g., result/graph500/iceberg/2way/toc4
```


