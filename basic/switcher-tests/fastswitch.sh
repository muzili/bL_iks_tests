# This script switch 100 times between big and little without waiting between
# switches

echo "fastswitch : switch 100 times between big and little without waiting \
between switches"

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

fastswitch_to_big () {
  for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $BIG > $file
	echo "Switch to big"
  done
}

fastswitch_to_little () {
  for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $LITTLE > $file
  	echo "Switch to little"
  done
}

i=0
while [ $i -lt 100 ]; do
  fastswitch_to_little
  # consider cpuinfo_transition_latency before switching again to big 
  usleep 50000
  fastswitch_to_big
  i=$(($i + 1))
done

echo "SUCCESS!!"
exit 0
