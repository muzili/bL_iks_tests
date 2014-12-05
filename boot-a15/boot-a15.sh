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

usage()
{
	echo ""
	echo "usage: $0 -c <cpu number> [Optional Arguments...]"
	echo "Options: -c           operate on this cpu, this option can be specified multiple times"
	echo ""
	echo "Example: $0 -c 0 -c 1 ... -c $large_cpu_number"
	exit 1
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
	check_kernel_oops
}

switch()
{
	CUR_FREQ=`cat /sys/devices/system/cpu/cpu"$CPU_NUM"/cpufreq/cpuinfo_cur_freq`
	if [ -z $CUR_FREQ ]; then
		echo "Unable to get current operating frequency"
		exit 1
	fi
	if [ "$CUR_FREQ" -eq "$LITTLE" ]; then
		echo "cpu$CPU_NUM is LITTLE. Switching to big.."
		bl-agitator -f big -c $CPU_NUM
		ERR_CODE=$?
		if [ $ERR_CODE -ne 0 ]; then
			echo "bigLITTLE switcher failed for cpu$CPU_NUM. Abort!!"
			exit 1
		else
			echo "cpu$CPU_NUM successfully switched to big."
		fi
	else if [ "$CUR_FREQ" -eq "$BIG" ]; then
		echo "cpu$CPU_NUM is big"
	else if [ "$CUR_FREQ" -gt "$LITTLE" ]; then
		if [ "$CUR_FREQ" -lt "$BIG" ]; then
			echo "cpu$CPU_NUM is LITTLE. Switching to big.."
			bl-agitator -f big -c $CPU_NUM
			ERR_CODE=$?
			if [ $ERR_CODE -ne 0 ]; then
				echo "bigLITTLE switcher failed for cpu$CPU_NUM. Abort!!"
				exit 1
			else
				echo "cpu$CPU_NUM successfully switched to big."
			fi
		fi
	else
		echo "cpu$CPU_NUM operating at Current Frequency = $CUR_FREQ"
		exit 1
	fi
	fi
	fi
}

TOTAL_ACTIVE_CPUS=`ls /sys/devices/system/cpu/cpu*/online | wc -l`
large_cpu_number=$((TOTAL_ACTIVE_CPUS-1))

if [ $(echo "$2" | grep -E "^[0-$large_cpu_number]+$") ]; then
	echo "Running $0 $1 $2"
else
	echo "Error: Specify the number of CPU core (0-$large_cpu_number) to be switched to the desired frequency"
	usage
fi

# insert bl module is intended for RTSM
MODEL=`cat /proc/device-tree/model`
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	echo "insert bl module from boot-a15.sh"
	insert_bl_module
fi

BIG=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
LITTLE=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq`

while [ "$1" ]; do
	case "$1" in
        -c|--cpu-num)
                if [ -z "$2" ]; then
                        echo "Error: Specify the CPU core (0-$large_cpu_number) to be switched to the desired frequency"
                        usage
                fi
                if [ $(echo "$2" | grep -E "^[0-$large_cpu_number]+$") ]; then
                        CPU_NUM=$2;
                        switch
                        shift;
                else
                        usage
                fi
                ;;
	-h | --help | *)
		usage
		;;
	esac
	shift;
done

check_kernel_oops

exit 0
