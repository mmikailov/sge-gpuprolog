#!/bin/sh

#
# Startup script to allocate GPU devices.
# Original version by: Kota Yamaguchi 2015 <kyamagu@vision.is.tohoku.ac.jp>
#
# Version 2, 12/30/2020

# LOG_FILE=${SGE_O_WORKDIR}/prolog_epilog_log_${JOB_ID}_${SGE_TASK_ID}.txt
LOG_FILE=/dev/null

echo "================= start job ${JOB_ID} ============" > ${LOG_FILE}
echo "----- In prolog -----" >> ${LOG_FILE}

QSTAT=/opt/sge_root/bin/lx-amd64/qstat

# Input: type of GPU (gpu)
# Returns number of GPU of this type requested
GpuNum () {
   echo "GPU type: $1" >> ${LOG_FILE}
   NG=$($QSTAT -j $JOB_ID | \
        sed -n "s/hard resource_list:.*$1=\([[:digit:]]\+\).*/\1/p")
        
	if [ -z $NG ]
	then
		echo "Zero GPUs type of [$1] were requested." >> ${LOG_FILE}
		return 0 
  	else 
  		echo "Requested $NG GPUs type of [$1]." >> ${LOG_FILE}
  	fi
	return $NG
}  # end of GpuNum ()

device_ids=$(nvidia-smi -L | cut -f1 -d":" | cut -f2 -d" " | xargs shuf -e)

# Returns number of not locked GPUs
NotLockedGpus () {
	nlgp=0
	for device_id in $device_ids
	do
	  lockfile=/tmp/lock-gpu$device_id
	  [[ ! -d $lockfile ]] && nlgp=$(expr $nlgp + 1)
	done
	return $nlgp
} # end of NotLockedGpus


NotLockedGpus
NOT_LOCKED_GPUS=$?		# return value from NotLockedGpus ()

# Query how many gpus to allocate.

# Check if "gpu" type of GPUs were requested
GpuNum gpu
NGPUS=$?		# return value from GpuNum ()		

if [ $NGPUS -le 0 ]
then
  echo "Negative or zero number of GPUs were requested." >> ${LOG_FILE}
  exit 0
fi

NGPUS=$(expr $NGPUS \* ${NSLOTS=1}) 

ENV_FILE=$SGE_JOB_SPOOL_DIR/environment 

# Allocate and lock GPUs.
export SGE_GPU=""
i=0

# Release (unlock) all GPUs which are not in use (memory used = 0) if not enough of them were found unlocked  
echo "Release (unlock) all GPUs which are not in use (memory used = 0) if not enough of them were found unlocked." >> ${LOG_FILE}
if [ $NOT_LOCKED_GPUS -lt $NGPUS ]
then
	mem_use=($(nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits)) # returns memory used by all GPUs
	echo "Clean up" >> ${LOG_FILE}
	for device_id in $device_ids
	do
	  	lockfile=/tmp/lock-gpu$device_id
		if [ -d $lockfile ] && [ ${mem_use[$device_id]} -eq 0  ]
	  	then
	    	   rmdir $lockfile
	    	   echo "Removed $lockfile in prolog." >> ${LOG_FILE}
		fi
	done
fi

# lock GPUs
i=0
for device_id in $device_ids
do
  lockfile=/tmp/lock-gpu$device_id
  if mkdir $lockfile
  then
  	echo "Locked $lockfile in prolog." >> ${LOG_FILE}
    SGE_GPU="$SGE_GPU $device_id"
    i=$(expr $i + 1)
    if [ $i -ge $NGPUS ]
    then
      break
    fi
  fi
done

if [ $i -lt $NGPUS ]
then
  echo "ERROR: Only reserved $i of $NGPUS requested devices."
  echo "ERROR: Only reserved $i of $NGPUS requested devices." >> ${LOG_FILE}
  [[ $i -eq 0 ]] && exit 101
fi

echo "SGE_GPU=$SGE_GPU" >> ${LOG_FILE}

# Set the environment.
# echo SGE_GPU="$(echo $SGE_GPU | sed -e 's/^ //' | sed -e 's/ /,/g')" >> $ENV_FILE
echo CUDA_VISIBLE_DEVICES="$(echo $SGE_GPU | sed -e 's/^ //' | sed -e 's/ /,/g')" >> $ENV_FILE
echo "Success prolog." >> ${LOG_FILE}
exit 0 
