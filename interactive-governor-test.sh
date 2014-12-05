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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Amit Pundir <amit.pundir@linaro.org>
# Modified-by: Naresh Kamboju <naresh.kamboju@linaro.org> 
#

get_governor()
{
	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules
	if [ -d $ANDROID_MOD_PATH ]; then
		GOVERNOR="interactive"
	else if [ -d $UBUNTU_MOD_PATH ]; then
			GOVERNOR="ondemand"
		else
			echo "ERROR: get_governors failed"
			exit 1
		fi
	fi
}

check_kernel_oops()
{
	KERNEL_ERR=`dmesg | grep "Unable to handle kernel "`
	if [ -n "$KERNEL_ERR" ]; then
		echo "Kernel OOPS. Abort!!"
		exit 1
	fi
}

insert_bl_module()
{
	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules/`uname -r`/kernel/drivers/cpufreq
	if [ -d $ANDROID_MOD_PATH ]; then
		MOD_LOCATION=$ANDROID_MOD_PATH/arm-bl-cpufreq.ko
		GOVERNOR="interactive"
	else if [ -d $UBUNTU_MOD_PATH ]; then
			MOD_LOCATION=$UBUNTU_MOD_PATH/arm-bl-cpufreq.ko
			GOVERNOR="ondemand"
		else
			echo "ERROR: No arm-bl-cpufreq.ko module found"
			exit 1
		fi
	fi
	CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
	if [ -z "$CPU_FREQ_KM" ]; then
		insmod $MOD_LOCATION
	fi
	check_kernel_oops
}

set_governor()
{
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
		do echo $GOVERNOR > $file
	done
	sleep 5;
}

reset_governor()
{
	GOVERNOR="userspace"
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
		do echo $GOVERNOR > $file
	done
	sleep 5;
}

check_operating_frequency()
{
	i=0
	for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
		do freq=`cat $file`
		if [ "$freq" -eq "$BIG" ]; then
			echo "cpu$i operating in BIG mode at $freq"
		else if [ "$freq" -eq "$LITTLE" ] ; then
			echo "cpu$i operating in LITTLE mode at $freq"
		else
			echo "cpu$i operating at $freq"
		fi
		fi
		i=$((i+1))
	done
}

run_memtester()
{
	memtester 1M 1 &
	sleep 5;
	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules
	if [ -d $ANDROID_MOD_PATH ]; then
		while [ `ps  | grep -v grep | grep memtester | wc -l` -eq 1 ]; do
			check_operating_frequency
			sleep 20;
		done
	else if [ -d $UBUNTU_MOD_PATH ]; then
		while [ `ps ax | grep -v grep | grep memtester | wc -l` -eq 1 ]; do
			check_operating_frequency
			sleep 20;
		done
	else
		echo "ERROR: Unexpected Environment "
		exit 1
        fi
	fi
}

# insert bl module is intended for RTSM
MODEL=`cat /proc/device-tree/model`
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	echo "insert bl module from interactive-governor-test.sh"
	insert_bl_module
fi

BIG=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
LITTLE=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`

get_governor
set_governor
check_operating_frequency
run_memtester
check_operating_frequency
reset_governor

exit 0
