# Copyright (C) 2013, Linaro Limited.
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

usage()
{
        echo ""
        echo "usage: $0 [<option> <argument>] .."
        echo ""
        echo "Options: -f <operating frequency> [big/little; Default: big]"
        echo "         -c <operate on this cpu> [this option can be specified multiple times]"
        echo "         -d <take this cpu offline>"
        echo "         -e <bring this cpu online>"
        echo "         -s <periodic switching interval in msec> [Default: 50]"
        echo "         -r <random switching seed> [Default: 100]"
        echo "         -l <random switching seed limit> [Default: 1000]"
        echo "         -n <threads to be executed on specific cpus>"
        echo ""
        echo "Example of periodic switching: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -s 50"
        echo "Example of random switching: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -r 100 -l 1000"
        echo "Example of periodic switching while spawning threads on cpu0 and cpu3: $0 -f big -c 0 -c 1 ... -c $large_cpu_number -n 0 ... $large_cpu_number -s 50"
        exit 1
}

IO_STATUS=0;
SWITCHER_STATUS=0;
PERF_STATUS=0;
OUTFILE="/data/local/each-perf-disk-io-output.txt"
EVENTS="stat -o $OUTFILE -e ARMv7_Cortex_A15/config=17/ -e ARMv7_Cortex_A7/config=17/"
FILE="/data/local/perf-disk-io-output.txt"

rm -rf $FILE 
rm -rf $OUTFILE 

total_no_of_cpu=`cat /proc/cpuinfo | grep proc | wc -l`
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

run_perf_iozone()
{
	i=$1
	while test $i -gt 0 ; do
		echo ""
		echo "Running iozone -a -i 0 -i 2 -s 16m -V teststring"
		perf $EVENTS iozone -a -i 0 -i 2 -s 16m -V teststring
		ERR_CODE=$?
		if [ $ERR_CODE -ne 0 ]; then
			echo "iozone failed. Abort!!"
			IO_STATUS=$ERR_CODE;
			return 1
		else
			echo "iozone finished successfully"
		fi

		if ( test "$NON_SWITCHER" = "y" ) 
		then
		  non_zero_count=`grep $NON_ZERO_COUNT $OUTFILE | cut -d"A" -f1`
		  zero_count=`grep $ZERO_COUNT $OUTFILE | cut -d"A" -f1`
		  if ( test $non_zero_count -ne 0 && test $zero_count = 0 )
		    then
			echo "event count on active cluster $CLUSTER is $non_zero_count"
			echo "event count on in-active cluster $IN_ACTIVE_CLUSTER count is $zero_count"
		  else
			echo "event count on active cluster $CLUSTER is $non_zero_count"
			echo "event count on in-active cluster $IN_ACTIVE_CLUSTER count is $zero_count"
			echo "TEST FAILED"
			PERF_STATUS=1
		  fi
		else if ( test "$SWITCHER" = "y" )
		then
		  a15_event_count=`grep ARMv7_Cortex_A15 $OUTFILE | cut -d"A" -f1`
		  a7_event_count=`grep ARMv7_Cortex_A7 $OUTFILE | cut -d"A" -f1`
		  if ( test $a15_event_count -ne 0 && test $a7_event_count -ne 0 )
		    then
		  	echo "a15_event_count= $a15_event_count"
		  	echo "a7_event_count= $a7_event_count"
			echo "while switcher is active, the count is non zero on a15 and a7 clusters"
		  else
		  	echo "a15_event_count= $a15_event_count"
		  	echo "a7_event_count= $a7_event_count"
			echo "count zero on a15 and a7 clusters"
			echo "TEST FAILED"
			PERF_STATUS=1
		  fi
		else
			echo "Unknown mode"
		fi
		fi
		i=$(($i-1))
	done
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
        -a7|--a7-only)
                if [ $(echo "$2" | grep -E "^[1-2]+$") ]; then
			NON_ZERO_COUNT="ARMv7_Cortex_A7"
			ZERO_COUNT="ARMv7_Cortex_A15"
			NON_SWITCHER="y"
			CLUSTER="a7"
			IN_ACTIVE_CLUSTER="a15"
                        shift;
                fi
                ;;
        -a15|--a15-only)
                if [ $(echo "$2" | grep -E "^[1-2]+$") ]; then
			ZERO_COUNT="ARMv7_Cortex_A7"
			NON_ZERO_COUNT="ARMv7_Cortex_A15"
			NON_SWITCHER="y"
			CLUSTER="a15"
			IN_ACTIVE_CLUSTER="a7"
                        shift;
                fi
                ;;
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
        -s|--periodic-switching)
                if [ -z "$RANDOM_SWITCH" ]; then
                        PERIODIC_SWITCH=y;
                        if [ "$2" -gt 0 ]; then
                                INTR=$2;
                        else
                                INTR=50;
                        fi
			SWITCHER="y"
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
			SWITCHER="y"
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
	run_periodic_switcher
fi

if  [ "$RANDOM_SWITCH" = "y" ]; then
        if [ -z "$LIMIT" ]; then
                echo "Error: Specify the Seed Limit for the random switcher [-l 1000]"
                usage
	fi
        run_random_switcher
fi

run_perf_iozone 10

if  ([ "$PERIODIC_SWITCH" = "y" ] || [ "$RANDOM_SWITCH" = "y" ]); then
        kill_switcher
fi

if  ([ $IO_STATUS -ne 0 ] || [ $SWITCHER_STATUS -ne 0 ] || [ $PERF_STATUS -ne 0 ]); then
        echo "Test failed. Abort!!"
        exit 1
fi

KERNEL_ERR=`dmesg | grep "Unable to handle kernel "`
if  ([ -n "$KERNEL_ERR" ]); then
	echo "Kernel OOPS detected. Abort!!"
	exit 1
fi

exit 0
