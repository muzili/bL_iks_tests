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
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
#
# Assumes package ffmpeg is installed

usage()
{
        echo ""
        echo "usage: $0 [<option> <argument>] .."
        echo ""
        echo "Options: -f <operating frequency> [big/little; Default: big]"
        echo "         -c <operate on this cpu> [this option can be specified multiple times]"
        echo "         -d <take this cpu offline>"
        echo "         -e <bring this cpu online>"
	echo "         -i <number of iterations> [Default: 1]"
	echo "         -p <input file> [Default: /data/samples/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG]"
        echo "         -s <periodic switching interval in msec> [Default: 50]"
        echo "         -r <random switching seed> [Default: 100]"
        echo "         -l <random switching seed limit> [Default: 1000]"
        echo "         -n <threads to be executed on specific cpus>"
        echo "         -S single-sync Sequential half transition (e.g.: big->barrier->little->barrier)"
        echo ""
        echo "Example of periodic switching: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -s 50"
        echo "Example of random switching: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -r 100 -l 1000"
        echo "Example of periodic switching while spawning threads on cpu0 and cpu3: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -n 0 ... $large_cpu_number -s 50"
        echo "Example of simultaneous thread while spawning threads on all cpus: $0 -f big -c 0 -n 0 ... $large_cpu_number -s 100 -S"
        exit 1
}

VPF_OGG_STATUS=0;
SWITCHER_STATUS=0;

total_no_of_cpu=`ls /sys/devices/system/cpu/cpu*/online | wc -l`
large_cpu_number=$((total_no_of_cpu-1))

TASKSET=affinity_tools

CPU_FAST=
CPU_SLOW=

#ARM
IMPLEMENTER=0x41
#A7
PART_SLOW=0xc07
#A15
PART_FAST=0xc0f
eachslow=
eachfast=
EACH_CPU=

get_no_of_cpus ()
{
	cpu=0
	while [ $cpu -lt $total_no_of_cpu ];
	do
	$TASKSET -part $cpu,$IMPLEMENTER,$PART_SLOW >/dev/null
		if [ $? == 0 ] ; then
			eachslow=" -c "
			CPU_SLOW=$CPU_SLOW$eachslow$cpu
		fi
	$TASKSET -part $cpu,$IMPLEMENTER,$PART_FAST >/dev/null
		if [ $? == 0 ] ; then
			eachfast=" -c "
			CPU_FAST=$CPU_FAST$eachfast$cpu
		fi
		cpu=$((cpu+1))
	done
	EACH_CPU="$CPU_SLOW$CPU_FAST"
}

switch()
{
       if [ "$FREQ" -eq 0 ]; then
               boot_a15
       else if [ "$FREQ" -eq 1 ]; then
               boot_a7
       else
               echo "Error: Unknown Operating frequency. Has to be set to either \"big\" or \"little\""
               usage
       fi
       fi
}

boot_a15()
{
	echo ""
	echo "Switching to big mode if not already in."
	boot-a15.sh -c $CPU_NUM
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "boot-a15 failed. Abort!!"
		exit 1
	fi
}

boot_a7()
{
	echo ""
	echo "Switching to little mode if not already in."
	boot-a7.sh -c $CPU_NUM
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "boot-a7 failed. Abort!!"
		exit 1
	fi
}

disable_cpu()
{
	echo ""
	echo "Taking CPU$DISABLE_CPU offline .."
	STATUS=`cat /sys/devices/system/cpu/cpu$DISABLE_CPU/online`
	if [ $STATUS -eq 1 ]; then
		echo 0 > /sys/devices/system/cpu/cpu$DISABLE_CPU/online
	else
		echo "CPU$DISABLE_CPU already in offline mode."
	fi
}

enable_cpu()
{
	echo ""
	echo "Bringing CPU$ENABLE_CPU online .."
	STATUS=`cat /sys/devices/system/cpu/cpu$ENABLE_CPU/online`
	if [ $STATUS -eq 0 ]; then
		echo 1 > /sys/devices/system/cpu/cpu$ENABLE_CPU/online
	else
		echo "CPU$ENABLE_CPU already in online mode."
	fi
}

run_vfp_ffmpeg_ogg()
{
	# Set input file location for vfp-ffmpeg.sh
	if [ -z "$FILE" ]; then
		if [ -r /data/boxes/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG ]; then
			FILE=/data/boxes/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG;
		elif [ -r /usr/share/testdata/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG ]; then
			FILE=/usr/share/testdata/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG;
		fi
	fi
	if [ -z "$ITR" ]; then
		ITR=1;
	fi

	echo ""
	echo "Running vfp-ffmpeg.sh "$FILE" "$ITR""
	vfp-ffmpeg.sh $FILE $ITR
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo " vfp-ffmpeg.sh failed. Abort!!"
		VPF_OGG_STATUS=$ERR_CODE;
		return 1
	else
		echo "vfp-ffmpeg.sh finished successfully"
		return 0
	fi
}

run_periodic_switcher()
{
        echo ""
        echo "Starting bigLITTLE periodic switcher in the background"
        if [ -z "$THREAD_CPU0" ]; then
                bl-agitator -s $INTR &
                BL_AGITATOR_PID=$!
        else
		echo "spawning thread(s) on specified cpu(s)"
                echo "bl-agitator -n $EACH_CPU -s $INTR &"
                bl-agitator -n $EACH_CPU -s $INTR &
                BL_AGITATOR_PID=$!
        fi
        ERR_CODE=$?
        if [ $ERR_CODE -ne 0 ]; then
                echo "bigLITTLE periodic switcher failed. Abort!!"
                SWITCHER_STATUS=$ERR_CODE;
                return 1
        else
                return 0
        fi
}

run_random_switcher()
{
        echo ""
        echo "Starting bigLITTLE random switcher in the background"
        if [ -z "$THREAD_CPU0" ]; then
                bl-agitator -r $SEED -l $LIMIT &
                BL_AGITATOR_PID=$!
        else
		echo "spawning thread(s) on specified cpu(s)"
                echo "bl-agitator -n $EACH_CPU -r $SEED -l $LIMIT &"
                bl-agitator -n $EACH_CPU -r $SEED -l $LIMIT &
                BL_AGITATOR_PID=$!
        fi
        ERR_CODE=$?
        if [ $ERR_CODE -ne 0 ]; then
                echo "bigLITTLE random switcher failed. Abort!!"
                SWITCHER_STATUS=$ERR_CODE;
                return 1
        else
                return 0
        fi
}

simultaneous_thread_switcher()
{
        echo ""
        echo "Starting bigLITTLE simultaneous thread switcher in the background"
        if [ -z "$THREAD_CPU0" ]; then
                bl-agitator -s $INTR &
                BL_AGITATOR_PID=$!
        else
                echo "spawning thread(s) on specified cpu(s)"
                echo "bl-agitator -n $EACH_CPU -s $INTR -S &"
                bl-agitator -n $EACH_CPU -s $INTR -S &
                BL_AGITATOR_PID=$!
        fi
        ERR_CODE=$?
        if [ $ERR_CODE -ne 0 ]; then
                echo "bigLITTLE simultaneous thread switcher failed. Abort!!"
                SWITCHER_STATUS=$ERR_CODE;
                return 1
        else
                return 0
        fi
}

kill_switcher()
{
        echo ""
        ANDROID_MOD_PATH=/system/modules
        UBUNTU_MOD_PATH=/lib/modules
        if [ -d $ANDROID_MOD_PATH ]; then
            PID_BL_CHECK=`ps | grep "$BL_AGITATOR_PID" | grep "bl-agitator" | awk '{print $2}'`
        else if [ -d $UBUNTU_MOD_PATH ]; then
            PID_BL_CHECK=`ps ax | grep "$BL_AGITATOR_PID" | grep "bl-agitator" | awk '{print $1}'`
        else
           echo "ERROR: Unexpected Environment "
           exit 1
        fi
        fi
        echo "Kill bigLITTLE switcher BL_AGITATOR_PID $BL_AGITATOR_PID"
        echo "PID_BL_CHECK= $PID_BL_CHECK"

        if [ -z "$PID_BL_CHECK" ]; then
                echo "bigLITTLE switcher not running. Report Error!!"
                exit 1
        else
                # done with bl-agitator. Kill the process
                echo "sending SIGTERM BL_AGITATOR_PID $BL_AGITATOR_PID"
                kill $BL_AGITATOR_PID
                if [ -d $ANDROID_MOD_PATH ]; then
                    PID_BL_CHECK_AGAIN=`ps | grep "$BL_AGITATOR_PID" | grep "bl-agitator" | awk '{print $2}'`
                else if [ -d $UBUNTU_MOD_PATH ]; then
                    PID_BL_CHECK_AGAIN=`ps ax | grep "$BL_AGITATOR_PID" | grep "bl-agitator" | awk '{print $1}'`
                else
                    echo "ERROR: Unexpected Environment "
                    exit 1
                fi
                fi
                if [ -n "$PID_BL_CHECK_AGAIN" ]; then
                        #if the above kill is not successfull. kill forcefully
                        echo "sending SIGKILL BL_AGITATOR_PID $BL_AGITATOR_PID"
                        kill -9 $BL_AGITATOR_PID  > /dev/null  2>&1
		fi
        fi
}

if [ -z "$1" ]; then
	usage
fi

get_no_of_cpus

while [ "$1" ]; do
	case "$1" in
	-f|--frequency)
		if [ -z "$2" ]; then
			echo "Error: Specify the operating frequency [big/little]"
			usage
		fi
		if [ "$2" = "big" ]; then
			FREQ=0;
			shift;
		else if [ "$2" = "little" ]; then
			FREQ=1;
			shift;
		else
                        echo "Error: Operating frequency has to be set to either \"big\" or \"little\""
			usage
		fi
		fi
		;;
	-c|--cpu-num)
		if [ -z "$2" ]; then
			echo "Error: Specify the CPU core (0-$large_cpu_number) to be switched to the desired frequency"
			usage
		fi
		if [ $(echo "$2" | grep -E "^[0-$large_cpu_number]+$") ]; then
			CPU_NUM=$2;
			if [ -z "$FREQ" ]; then
                                echo "Error: Specify the operating frequency [big/little]"
                                usage
                        fi
                        switch
			shift;
		else
			usage
		fi
		;;
        -d|--disable-cpu)
                if [ $(echo "$2" | grep -E "^[1-3]+$") ]; then
                        DISABLE_CPU=$2;
			disable_cpu
                        shift;
                fi
                ;;
        -e|--enable-cpu)
                if [ $(echo "$2" | grep -E "^[1-3]+$") ]; then
                        ENABLE_CPU=$2;
			enable_cpu
                        shift;
                fi
                ;;
	-i|--iterations)
		if [ "$2" -gt 0 ]; then
			ITR=$2;
			shift;
		fi
		;;
	-p|--input-file)
		if [ -e "$2" ]; then
			FILE=$2;
			shift;
		fi
		;;
        -s|--periodic-switching)
                if [ -z "$RANDOM_SWITCH" ]; then
                        PERIODIC_SWITCH=y;
                        if [ "$2" -gt 0 ]; then
                                INTR=$2;
                        else
                                INTR=50;
                        fi
                else
                        echo "Invalid option (-s) !!"
                        echo "Can't do random and periodic switchings simultaneously"
                        echo "Set to Random switching mode"
                fi
                shift;
                ;;
        -r|--random-switching)
                if [ -z "$PERIODIC_SWITCH" ]; then
                        RANDOM_SWITCH=y;
                        if [ "$2" -gt 0 ]; then
                                SEED=$2;
                        else
                                SEED=100;
                        fi
                else
                        echo "Invalid option (-r) !!"
                        echo "Can't do random and periodic switchings simultaneously"
                        echo "Set to Periodic switching mode"
                fi
                shift;
                ;;
        -l|--seed-limit)
                if [ -z "$PERIODIC_SWITCH" ]; then
		        if [ -z "$SEED" ]; then
                                echo "Error: Specify the Seed for the random switcher [-r 100]"
                                usage
                        fi
                        if [ "$2" -gt 0 ]; then
                                LIMIT=$2;
                        else
                                LIMIT=1000;
                        fi
                else
                        echo "Invalid option (-l) !!"
                        echo "Can't do random and periodic switchings simultaneously"
                        echo "Set to Periodic switching mode"
                fi
                shift;
                ;;
        -n|--thread-switching)
                if [ $(echo "$2" | grep -E "^[0-$large_cpu_number]+$") ]; then
                        THREAD_CPU0="-c $2";
                        shift;
                else
                        echo "Error: Must specify at least one CPU on which thread has to be spawned"
                        usage
                fi
                shift;
                ;;
        -S|--simultaneous_thread_switching)
                if [ -z "$RANDOM_SWITCH" ]; then
                        SIMULTANEOUS_THREAD_SWITCH=y;
                else
                        echo "Invalid option (-S) !!"
                        echo "Can't do random and simultaneous thread switching at a time"
                        echo "Set to Random switching mode"
                fi
                ;;
	-h | --help | *)
		usage
		;;
	esac
	shift;
done

if [ -z "$FREQ" ]; then
        echo "Error: Frequency has to be set to either \"big\" or \"little\""
	usage
else if [ -z "$CPU_NUM" ]; then
	echo "Error: Specify the number of CPU core (0-$large_cpu_number) to be switched to the desired frequency"
	usage
fi
fi

if  [ "$PERIODIC_SWITCH" = "y" ]; then
	if [ "$SIMULTANEOUS_THREAD_SWITCH" = "y" ]; then
		echo ""
	else
		run_periodic_switcher
	fi
fi

if  [ "$RANDOM_SWITCH" = "y" ]; then
        if [ -z "$LIMIT" ]; then
                echo "Error: Specify the Seed Limit for the random switcher [-l 1000]"
                usage
	fi
        run_random_switcher
fi

if  [ "$SIMULTANEOUS_THREAD_SWITCH" = "y" ]; then
        simultaneous_thread_switcher
	cluster-status.sh $BL_AGITATOR_PID &
fi

run_vfp_ffmpeg_ogg

if  ([ "$PERIODIC_SWITCH" = "y" ] || [ "$RANDOM_SWITCH" = "y" ] || [ "$SIMULTANEOUS_THREAD_SWITCH" = "y" ]); then
        kill_switcher
fi

if  ([ $VPF_OGG_STATUS -ne 0 ] || [ $SWITCHER_STATUS -ne 0 ]); then
        echo "Test failed. Abort!!"
        exit 1
fi

KERNEL_ERR=`dmesg | grep "Unable to handle kernel "`
if [ -n "$KERNEL_ERR" ]; then
	echo "Kernel OOPS detected. Abort!!"
	exit 1
fi

exit 0
