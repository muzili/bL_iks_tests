# This script try to remove mod in different configurations

echo "try_rmmod : try to remove mod in different configurations"

REINSMOD=1
ANDROID_MOD_PATH=/system/modules
UBUNTU_MOD_PATH=/lib/modules/`uname -r`/kernel/drivers/cpufreq
if [ -d $ANDROID_MOD_PATH ]; then
    MOD_LOCATION=$ANDROID_MOD_PATH/arm-bl-cpufreq.ko
    CPU_FREQ_KM=`lsmod | busybox grep cpufreq | busybox awk '{print $1}'`
else if [ -d $UBUNTU_MOD_PATH ]; then
    MOD_LOCATION=$UBUNTU_MOD_PATH/arm-bl-cpufreq.ko
    CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
else
    echo "ERROR: No arm-bl-cpufreq.ko module found"
    exit 1
fi
fi

if ! [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
  insmod $MOD_LOCATION
  REINSMOD=0
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
	do freq=`cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq`
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
	do freq=`cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq`
	if [ "$freq" -eq "$LITTLE " ]
	then
		echo "Switch to big with success"
	else
		echo ERROR : $freq
		exit 1
	fi
  done
}

switch_to_little
rmmod arm-bl-cpufreq
if lsmod | grep arm_bl_cpufreq > /dev/null
  then
    echo "ERROR : failed to remove module (little)"
    exit 1
fi

insmod $MOD_LOCATION
switch_to_big
rmmod arm-bl-cpufreq
if lsmod | grep arm_bl_cpufreq > /dev/null
  then
    echo "ERROR : failed to remove module (big)"
    exit 1
fi

if [ "$REINSMOD" -eq "1" ]
  then
    insmod $MOD_LOCATION
fi

echo "SUCCESS!!"
exit 0
