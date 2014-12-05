# This script switch 5 times on the same cluster, checking switcher behavior is
# consistent

echo "reswitch : switch 5 times on the same cluster, and check if switcher \
behavior is consistent"

insert_bl_module()
{
	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules/`uname -r`/kernel/drivers/cpufreq
	if [ -d $ANDROID_MOD_PATH ]; then
		MOD_LOCATION=$ANDROID_MOD_PATH/arm-bl-cpufreq.ko
	else if [ -d $UBUNTU_MOD_PATH ]; then
		MOD_LOCATION=$UBUNTU_MOD_PATH/arm-bl-cpufreq.ko
	else
		echo "ERROR: No arm-bl-cpufreq.ko module found"
		exit 1
	fi
	fi
	CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
	if [ -z "$CPU_FREQ_KM" ]; then
	insmod $MOD_LOCATION
	fi
}

# insert bl module is intended for RTSM
MODEL=`cat /proc/device-tree/model`
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	insert_bl_module
fi

BIG=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
LITTLE=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`

switch_to_big () {

  for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $BIG > $file
  done

  # consider cpuinfo_transition_latency before checking
  usleep 50000

  for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do freq=`cat $file`
	if [ "$freq" -eq "$BIG" ]
	then
		echo "Switch to big with success"
	else
		echo ERROR : $freq
		exit 1
	fi
  done
}

switch_to_little () {

  for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $LITTLE > $file
  done

  # consider cpuinfo_transition_latency before checking
  usleep 50000

  for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do freq=`cat $file`
	if [ "$freq" -eq "$LITTLE " ]
	then
		echo "Switch to big with success"
	else
		echo ERROR : $freq
		exit 1
	fi
  done
}

i=0
while [ $i -lt 5 ]; do
  switch_to_little
  i=$(($i + 1))
done

i=0
while [ $i -lt 5 ]; do
  switch_to_big
  i=$(($i + 1))
done

echo "SUCCESS!!"
exit 0
