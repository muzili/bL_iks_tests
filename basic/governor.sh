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

echo "Trying to set invalid governor..."
TCID=bl-governor-invalid01
echo xxxxxx > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
ERR_CODE=$?
#This one should fail
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : PASS"
else
   echo "$TCID : FAIL"
fi

echo "Setting governor to userspace on all cores..."
TCID=bl-governor-userspace01
ERR_CODE=0
GOVERNOR="userspace"
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do echo $GOVERNOR > $file
ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

echo "Verifying governors set to userspace on all cores..."
TCID=bl-governor-userspace02
ERR_CODE=0
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
grep userspace $file > /dev/null
ERR_CODE=$(( $ERR_CODE+$? ))
done

if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi
