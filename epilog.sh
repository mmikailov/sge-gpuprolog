#!/bin/sh
#
# Finish script to release GPU devices.
#
# Original vdersion by: Kota Yamaguchi 2015 <kyamagu@vision.is.tohoku.ac.jp>

# LOG_FILE=${SGE_O_WORKDIR}/prolog_epilog_log_${JOB_ID}_${SGE_TASK_ID}.txt
LOG_FILE=/dev/null
echo "----- In epilog -----" >> ${LOG_FILE}

ENV_FILE=$SGE_JOB_SPOOL_DIR/environment

if test "${SGE_GPU+x}"; then
	echo "SGE_JOB_SPOOL_DIR is set" >> ${LOG_FILE}
else
    echo "SGE_JOB_SPOOL_DIR is not set" >> ${LOG_FILE}
    exit 0
fi

# echo "ENV_FILE = $ENV_FILE" >> ${LOG_FILE}
# ls -alsh $ENV_FILE  >> ${LOG_FILE}

if [ ! -f $ENV_FILE -o ! -r $ENV_FILE ]
then
  echo "ERROR: The environment file is NOT readable." >> ${LOG_FILE}
fi

# Remove lock files.
device_ids=$(grep SGE_GPU $ENV_FILE | \
             sed -e "s/,/ /g" | \
             sed -n "s/SGE_GPU=\(.*\)/\1/p" | \
             xargs shuf -e)
	             
for device_id in $device_ids
do
  lockfile=/tmp/lock-gpu$device_id
  if [ -d $lockfile ]
  then
    rmdir $lockfile
    echo "Removed $lockfile in epilog." >> ${LOG_FILE}
  fi
done

echo "Success epilog." >> ${LOG_FILE}

exit 0

