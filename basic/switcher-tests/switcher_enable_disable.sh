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
# ==== switcher_enable_disable.sh description ====
# new feature "CONFIG_BL_SWITCHER=y" is added in kernel.
# enable and disable switcher can be done in run time.
# cat /sys/kernel/bL_switcher/active
# switcher_enable_disable.sh disable and enable switcher 100 times.

ERR_CODE=0
switcher_disable ()
{
	echo 0 > /sys/kernel/bL_switcher/active
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "not able to disable switcher"
		echo "switcher_enable_disable.sh FAILED"
		exit 1
	fi
}

switcher_enable ()
{
	echo 1 > /sys/kernel/bL_switcher/active
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "not able to enable switcher"
		echo "switcher_enable_disable.sh FAILED"
		exit 1
	fi
}

i=0
while [ $i -lt 100 ]; do
  switcher_disable
  usleep 50000
  switcher_enable
  i=$(($i + 1))
done

echo "switcher_enable_disable.sh SUCCESS!!"
exit 0
