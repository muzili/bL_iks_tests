# Copyright (C) 2012, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301,    USA.
#
# Author: Paul Larson <paul.larson@linaro.org>
# Modified-by: Naresh Kamboju <naresh.kamboju@linaro.org> 
#

insert_bl_module()
{
	#SETUP
	#Remove the module just in case
	rmmod arm_bl_cpufreq > /dev/null  2>&1
	rmmod cpufreq_ondemand > /dev/null  2>&1

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

	echo "Loading cpufreq driver module..."
	insmod $MOD_LOCATION
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "not able to insert arm-bl-cpufreq.ko module"
	fi
}

# insert bl module is intended for RTSM
MODEL=`cat /proc/device-tree/model`
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	insert_bl_module
fi

BIG=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
LITTLE=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`

ERR_CODE=0
echo "Initially set all cores to a15..."
TCID=bl-switch-all-a15

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $BIG > $file
	ERR_CODE=$(( $ERR_CODE+$? ))
done
 
# consider cpuinfo_transition_latency before checking
usleep 50000

for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do mode=`cat $file`
	[ $mode = $BIG ]
	ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

ERR_CODE=0
echo "Switch all cores from a15 to a7..."
TCID=bl-switch-all-a15-a7

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $LITTLE > $file
	ERR_CODE=$(( $ERR_CODE+$? ))
done

# consider cpuinfo_transition_latency before checking
usleep 50000

for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do mode=`cat $file`
	[ $mode = $LITTLE ]
	ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

ERR_CODE=0
echo "Switch all cores from a7 to a7..."
TCID=bl-switch-all-a7-a7

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $LITTLE > $file
	ERR_CODE=$(( $ERR_CODE+$? ))
done

# consider cpuinfo_transition_latency before checking
usleep 50000

for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do mode=`cat $file`
	[ $mode = $LITTLE ]
	ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

ERR_CODE=0
echo "Switch all cores from a7 to a15..."
TCID=bl-switch-all-a7-a15

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $BIG > $file
	ERR_CODE=$(( $ERR_CODE+$? ))
done

# consider cpuinfo_transition_latency before checking
usleep 50000

for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do mode=`cat $file`
	[ $mode = $BIG ]
	ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

ERR_CODE=0
echo "Switch all cores from a15 to a15..."
TCID=bl-switch-all-a15-a15

for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed
	do echo $BIG > $file
	ERR_CODE=$(( $ERR_CODE+$? ))
done

# consider cpuinfo_transition_latency before checking
usleep 50000

for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
	do mode=`cat $file`
	[ $mode = $BIG ]
	ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi
