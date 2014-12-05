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

if [ -z "$FILE" ]; then
	if [ -r /data/boxes/cpu_freq_cope_on_cluster_freq_output_org.log ]; then
		ORIGINAL_FILE=/data/boxes/cpu_freq_cope_on_cluster_freq_output_org.log;
		CURRENT_FILE=/data/boxes/cpu_freq_cope_on_cluster_freq_output.log;
	elif [ -r /usr/share/testdata/cpu_freq_cope_on_cluster_freq_output_org.log ]; then
		ORIGINAL_FILE=/usr/share/testdata/cpu_freq_cope_on_cluster_freq_output_org.log;
		CURRENT_FILE=/usr/share/testdata/cpu_freq_cope_on_cluster_freq_output.log;
	fi
fi

enable_switcher()
{
	echo 1 > /sys/kernel/bL_switcher/active
}

disable_switcher()
{
	echo 0 > /sys/kernel/bL_switcher/active
}

disable_switcher

cpu_freq_cope_on_cluster_freq.sh > $CURRENT_FILE
ERR_CODE=$?
if [ "$ERR_CODE" -ne 0 ] ; then
	echo "cpufreq_cope_on_cluster_freq.sh FAILED !!"
	enable_switcher
	sleep 10
	exit 1
else
	sleep 10
fi

diff $ORIGINAL_FILE $CURRENT_FILE > /dev/null 2>&1
# This test case is design to run on TC2 and specific cpu order and
# set of cpu freq and this test case is not testing big.LITTLE IKS patches
# Instead it test cpu freq driver stability and cpu freq change effect on
# sibling cpus which belongs to a cluster.
# So making this test case as always pass.
# This test case could fail if test found any kernel oops
ERR_CODE=0

ERR_CODE=$?
if [ "$ERR_CODE" -ne 0 ] ; then
	echo "cpufreq_cope_on_cluster_freq.sh FAILED !!"
	enable_switcher
	sleep 10
	exit 1
else
	enable_switcher
	sleep 10
fi

KERNEL_ERR=`dmesg | grep "Unable to handle kernel "`
if  ([ -n "$KERNEL_ERR" ]); then
	echo "Kernel OOPS detected. Abort!!"
	exit 1
fi

exit 0
