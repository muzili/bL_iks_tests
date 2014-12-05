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

# bl-agitator is able to switch tasks from one cluster to other cluster        
# at a time. we have to have validate it by reading the cluster status
# registers 0x6000000c and 0x60000010 of cluster_0 and cluster_1.
# Here we are using devmem tool/binary to read these locations.

#bl-agitator pid
PID=$1 

CLUSTER_0=0
CLUSTER_1=0

get_no_of_cpu()
{
	TOTAL_ACTIVE_CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	if [ $TOTAL_ACTIVE_CPUS -eq 2 ]; then
		CLUSTER_0_ADDR=0x7fff0018
		CLUSTER_1_ADDR=0x7fff0018
	else if [ $TOTAL_ACTIVE_CPUS -eq 4 ]; then
		CLUSTER_0_ADDR=0x6000000c
		CLUSTER_1_ADDR=0x60000010
	else
		echo " unknown architecture"
		exit 1
	fi
	fi
}

get_no_of_cpu

if [ -x /usr/bin/devmem ]
then
    DEVMEM="/usr/bin/devmem"
elif [ -x /bin/busybox ]
then
    DEVMEM="/bin/busybox devmem"
elif [ -x /system/bin/devmem ]
then
    DEVMEM="/system/bin/devmem"
else
    echo "ERROR: devmem binary not found"
    exit 1
fi

while kill -0 $PID ; do
# loop until bl-agitator is alive
   echo ""
   CLUSTER_0=`$DEVMEM $CLUSTER_0_ADDR`
   echo "CLUSTER_0 = $CLUSTER_0"
   if [ "$CLUSTER_0" = "0x5FFFF000" ]; then
	echo "CLUSTER_0 is shutdown"
   else
	echo "CLUSTER_0 is running"
   fi

   CLUSTER_1=`$DEVMEM $CLUSTER_1_ADDR`
   echo "CLUSTER_1 = $CLUSTER_1"
   if [ "$CLUSTER_1" = "0x40001FFF" ]; then
	echo "CLUSTER_1 is shutdown"
   else
	echo "CLUSTER_1 is running"
   fi

   if ([ "$CLUSTER_1" = "0x40001FFF" ] || [ "$CLUSTER_0" = "0x5FFFF000" ]); then
	# do nothing
	echo -ne ""
   else
	echo " Test failed !!!"
	exit 1
  fi

  sleep 1
done
