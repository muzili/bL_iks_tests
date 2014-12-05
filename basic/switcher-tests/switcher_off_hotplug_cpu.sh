#
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
# ==== switcher_off_hotplug_cpu.sh description ====
# when switcher is disabled in run time, we can get cpu2, cpu3 and cpu4 also online
# total we can see 5 cpus online. this test will hot-plug cpus 1,2,3 and 4.
# hot-plug cpus randomly one after other for 100 loops on each four different ways.
# ensure there would not be any kernel crash
# enable back the switcher after test

echo 0 > /sys/kernel/bL_switcher/active
i=0
while [ $i -lt 100 ];
do
echo 0 > /sys/devices/system/cpu/cpu1/online
echo 0 > /sys/devices/system/cpu/cpu2/online
echo 0 > /sys/devices/system/cpu/cpu3/online
echo 0 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu1/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu3/online
echo 1 > /sys/devices/system/cpu/cpu4/online
i=$(($i + 1))
done
echo 1 > /sys/kernel/bL_switcher/active

echo 0 > /sys/kernel/bL_switcher/active
i=0
while [ $i -lt 100 ];
do
echo 0 > /sys/devices/system/cpu/cpu1/online
echo 1 > /sys/devices/system/cpu/cpu1/online
echo 0 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 0 > /sys/devices/system/cpu/cpu3/online
echo 1 > /sys/devices/system/cpu/cpu3/online
echo 0 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu4/online
i=$(($i + 1))
done
echo 1 > /sys/kernel/bL_switcher/active

echo 0 > /sys/kernel/bL_switcher/active
i=0
while [ $i -lt 100 ];
do
echo 0 > /sys/devices/system/cpu/cpu1/online
echo 0 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu1/online
echo 0 > /sys/devices/system/cpu/cpu3/online
echo 0 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu3/online
i=$(($i + 1))
done
echo 1 > /sys/kernel/bL_switcher/active

echo 0 > /sys/kernel/bL_switcher/active
i=0
while [ $i -lt 100 ];
do
echo 0 > /sys/devices/system/cpu/cpu3/online
echo 0 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu3/online
echo 0 > /sys/devices/system/cpu/cpu1/online
echo 0 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu1/online
i=$(($i + 1))
done
echo 1 > /sys/kernel/bL_switcher/active
echo "SUCCESS!!"
exit 0
