#!/bin/bash
#set -x

#variables
BASE=$PWD
GEM5_ORIGINAL_CLONE=$BASE

#qemu disk location
#do it manually
QEMU_DISK=$BASE/iceberg.img

cd ../
COPYDIR=$PWD
cd $BASE

#gem5 parallel running directories
GEM5_DIRECT=$COPYDIR/direct
GEM5_2WAY=$COPYDIR/2way
GEM5_4WAY=$COPYDIR/4way
GEM5_8WAY=$COPYDIR/8way
GEM5_FULLY=$COPYDIR/fully
GEM5_VANILLA=$COPYDIR/vanilla
#dirs=("direct" "2way" "4way" "8way" "fully")

#gem5 results directories
#WORKLOAD_NAME=hello
#WORKLOAD_NAME=gups
WORKLOAD_NAME=graph500
#WORKLOAD_NAME=xsbench

GEM5_RESULTS_DIR=result

#gem5 cmd line args
GEM5_MEM_SIZE=16384MB

#TLB entry rows
TLB_SIZE=1024

#CPUS reserved for running QEMU VM
NUM_CPUS=1

#Intializing TCP_PORT 
TCP_PORT=3460

#Iceberg TOC list
#toclist=(8 16 32 64)
toclist=(4)

#Associativity ways list
WAYS=2
waylist=(2 4 8)
waylist=(2)

#Some basic steps
sudo chown $USER /dev/kvm

GEM5_OPT_RENAME_EXT=$(basename $BASE)
#GEM5_OPT_NEW_NAME=gem5$GEM5_OPT_RENAME_EXT.opt

GEM5_OPT_NEW_NAME_ORIG=$GEM5_OPT_RENAME_EXT.opt
GEM5_OPT_NEW_NAME=$GEM5_OPT_RENAME_EXT.opt

echo $GEM5_OPT_RENAME_EXT
echo $GEM5_OPT_NEW_NAME



#create base repo
if [ ! -d $GEM5_ORIGINAL_CLONE ]
then
    #cd $GEM5_ORIGINAL_CLONE
    #git checkout iceberg-fs
    echo "before compiling"
fi

#compile linux and gem5
COMPILE() {
    source $GEM5_ORIGINAL_CLONE/scripts/setvars.sh
    $GEM5_ORIGINAL_CLONE/compile.sh
    sudo chown -R $USER $GEM5_ORIGINAL_CLONE/gem5-custom
    cp $GEM5_ORIGINAL_CLONE/gem5-custom/build/X86/gem5.opt $GEM5_ORIGINAL_CLONE/gem5-custom/build/X86/$GEM5_OPT_NEW_NAME
}

#creating a clone of the gem5 for a specific way
create_target_gem5_dirs() {

	TARGET_DIR=$1
	ASSOC_CONFIG=$2

	if [ ! -d $TARGET_DIR ]
	then
	    echo "creating $ASSOC_CONFIG way dir..."
	    mkdir $TARGET_DIR
	    echo "copying to $TARGET_DIR..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $TARGET_DIR
	fi
}


#functions to run single gem5, wait for completion, kill process and collect result
#function to collect results
move_stats_to_results_dir () {
    STAT_FILE=$1
    TLB_SET_ASSOC=$2
    ICEBERG_ENABLED=$3
    TOC_LEN=$4
    RESULT_SUBDIR=vanilla
    if [ $ICEBERG_ENABLED -eq 1 ]
    then
        RESULT_SUBDIR=iceberg
    fi
    RESULT_SUBDIR="${RESULT_SUBDIR}/${TLB_SET_ASSOC}way"
    if [ $ICEBERG_ENABLED -eq 1 ]
    then
        RESULT_SUBDIR="${RESULT_SUBDIR}/toc${TOC_LEN}"
    fi
    RESULT_LOCATION=$BASE/$GEM5_RESULTS_DIR/$WORKLOAD_NAME/$RESULT_SUBDIR
    #echo $RESULT_LOCATION
    if [ ! -d $RESULT_LOCATION ]
    then
        mkdir -p $RESULT_LOCATION
    fi

    echo "Writing output to $RESULT_LOCATION"
    mv $STAT_FILE $RESULT_LOCATION
    #echo "mv $STAT_FILE $RESULT_LOCATION"

}

#function to check output file exist
check_tlblogs_exist () {

    FILE=$1/m5out/stats.txt	
    TLBLOGS=$1/tlblogs

    while :
    do
	var=`cat $FILE | grep "sim_ticks" | awk '{print $2}'`;

	if [ ! -z "$var" ]
	then
		let val=$var
		#if [ -f $1 ]
		if [ "$val" -gt "10000" ]
		#then echo "reasonable output"; fi    
	        then
		    echo "reasonable output $GEM5_OPT_NEW_NAME"	
	            #need to work on it
        	    #kill <pid>
		    PID=`pidof $GEM5_OPT_NEW_NAME`; kill -9 $PID
		    sleep 2
		    PID=`pidof $GEM5_OPT_NEW_NAME`; kill -9 $PID

		    cat $TLBLOGS | grep "Vanilla TLB miss rate"
		    cat $TLBLOGS | grep "Mosaic TLB miss rate"

        	    #move tlblogs to result directory
            	   move_stats_to_results_dir $FILE $2 $3 $4
		   move_stats_to_results_dir $TLBLOGS $2 $3 $4

		   PID=`ps axf | grep run.sh | grep -v grep | awk '{print $1}'`;kill -9 $PID
        	fi
	fi		
        sleep 1
    done
}

#iceberg function
run_single_iceberg_config() {

    TLB_SET_ASSOC=$1
    TOC_LEN=$2
    GEM5_OPT=$3/gem5-custom/build/X86/$GEM5_OPT_NEW_NAME
    FS_CONFIG_SCRIPT=$3/gem5-custom/configs/example/fs.py
    LINUX_BINARY_LOCATION=$3/linux-4.17/vmlinux
    PORT=$4
    TLBLOGS_LOCATION=$3

    #clear the existing output
    rm $3/m5out/stats.txt    

    #build gem5 command line
    GEM5_CMDLINE="$GEM5_OPT $FS_CONFIG_SCRIPT --kernel $LINUX_BINARY_LOCATION --disk-image $QEMU_DISK --cpu-type X86KvmCPU --command-line \"earlyprintk=ttyS0 console=ttyS0 lpj=7999923 root=/dev/hda -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:22\" --caches --l2cache --mem-size $GEM5_MEM_SIZE --TCP_listening_port $4 --num-cpus $NUM_CPUS --tlb_num_entries $TLB_SIZE --tlb_set_associativity_L1 $TLB_SET_ASSOC --simulateIcebergTLB --toc_size $TOC_LEN"

    echo "check_tlblogs_exist $TLBLOGS_LOCATION $1 1 $2 & ( sleep 5 && python3 $BASE/test-scripts/gem5_client_$WORKLOAD_NAME.py $PORT) & sh -c "$GEM5_CMDLINE""
    #run gem5 cmd
    check_tlblogs_exist $TLBLOGS_LOCATION $1 1 $2 & ( sleep 5 && python3 $BASE/test-scripts/gem5_client_$WORKLOAD_NAME.py $PORT) & sh -c "$GEM5_CMDLINE" #&> out.txt
}

#venilla function
run_single_vanilla_config() {
    TLB_SET_ASSOC=$1
    GEM5_OPT=$2/gem5-custom/build/X86/gem5.opt
    FS_CONFIG_SCRIPT=$2/gem5-custom/configs/example/fs.py
    LINUX_BINARY_LOCATION=$2/linux-4.17/vmlinux
    #build gem5 command line
    GEM5_CMDLINE="$GEM5_OPT $FS_CONFIG_SCRIPT --kernel $LINUX_BINARY_LOCATION --disk-image $QEMU_DISK --cpu-type X86KvmCPU --command-line \"earlyprintk=ttyS0 console=ttyS0 lpj=7999923 root=/dev/hda\" --caches --l2cache --mem-size $GEM5_MEM_SIZE --tlb_num_entries $TLB_SIZE --tlb_set_associativity_L1 $TLB_SET_ASSOC"
    #run gem5 cmd
    sh -c "$GEM5_CMDLINE"
}

create_exe_with_new_name() {

	NAME=$GEM5_OPT_NEW_NAME_ORIG
	ADD="WAYS-$1_TOC-$2"
	DIR=$3
	EXENAME=$ADD"-"$NAME
	
	echo "cp $GEM5_ORIGINAL_CLONE/gem5-custom/build/X86/gem5.opt $DIR/gem5-custom/build/X86/$EXENAME"
	cp $GEM5_ORIGINAL_CLONE/gem5-custom/build/X86/gem5.opt $DIR/gem5-custom/build/X86/$EXENAME

	GEM5_OPT_NEW_NAME=$EXENAME
}

#function to run gem5 in single TLB configuration
run_TLB_config() {

    TLB_CONFIG=$1

    #run iceberg
    GEM5_DIRECTORY=$GEM5_DIRECT

    if [ $TLB_CONFIG -eq  2 ]
    then
        GEM5_DIRECTORY=$GEM5_2WAY
    elif [ $TLB_CONFIG -eq  4 ]
    then
        GEM5_DIRECTORY=$GEM5_4WAY
    elif [ $TLB_CONFIG -eq  8 ]
    then
        GEM5_DIRECTORY=$GEM5_8WAY
    elif [ $TLB_CONFIG -eq $TLB_SIZE ]
    then
        GEM5_DIRECTORY=$GEM5_FULLY
    fi

    #Create a separate directory	
    create_target_gem5_dirs $GEM5_DIRECTORY $$TLB_CONFIG

    cd $GEM5_DIRECTORY

    for toc in ${toclist[@]}; do
   	create_exe_with_new_name $1 $toc $GEM5_DIRECTORY
        run_single_iceberg_config $1 $toc $GEM5_DIRECTORY $2
    done

    #run_single_iceberg_config $1 4 $GEM5_DIRECTORY
    #run vanilla
    #GEM5_DIRECTORY=$GEM5_VANILLA
    #run_single_vanilla_config $1 $GEM5_DIRECTORY
}

#COMPILE
#run_TLB_config $TLB_SIZE $TCP_PORT 
#sleep 5


for WAYS in ${waylist[@]}; do
	run_TLB_config $WAYS $TCP_PORT
done







#start running multiple gem5 parallely
#run_TLB_config 1 && run_TLB_config 2 && run_TLB_config 4 && run_TLB_config 8 && run_TLB_config $TLB_SIZE
#run_TLB_config 4 $TCP_PORT

#create directories and copy original to them
create_target_dirs() {

	if [ ! -d $GEM5_2WAY ]
	then
	    echo "creating 2way..."
	    mkdir $GEM5_2WAY
	    echo "copying to 2way..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $GEM5_2WAY
	fi

	if [ ! -d $GEM5_4WAY ]
	then
	    echo "creating 4way..."
	    mkdir $GEM5_4WAY
	    echo "copying to 4way..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $GEM5_4WAY
	fi

	if [ ! -d $GEM5_FULLY ]
	then
	    echo "creating fully..."
	    mkdir $GEM5_FULLY
	    echo "copying to fully..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $GEM5_FULLY
	fi

	if [ ! -d $GEM5_8WAY ]
	then
	    echo "creating 8way..."
	    mkdir $GEM5_8WAY
	    echo "copying to 8way..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $GEM5_8WAY
	fi

	if [ ! -d $GEM5_DIRECT ]
	then
	    echo "creating direct..."
	    mkdir $GEM5_DIRECT
	    echo "copying to direct..."
	    cp -a $GEM5_ORIGINAL_CLONE/. $GEM5_DIRECT
	fi
}


