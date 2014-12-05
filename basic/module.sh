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

# this test is intended for RTSM
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
TCID=bl-mod-load01
insmod $MOD_LOCATION
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

echo "Verifying cpufreq driver module loaded..."
TCID=bl-mod-load02
lsmod |grep arm_bl_cpufreq > /dev/null
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

echo "Loading cpufreq driver module when already loaded..."
TCID=bl-mod-load03
insmod $MOD_LOCATION
ERR_CODE=$?
#This one should fail
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : PASS"
else
   echo "$TCID : FAIL"
fi

echo "Unloading cpufreq driver module..."
TCID=bl-mod-unload01
rmmod arm_bl_cpufreq
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

echo "Verifying cpufreq driver module unloaded..."
TCID=bl-mod-unload02
lsmod |grep arm_bl_cpufreq > /dev/null
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : PASS"
else
   echo "$TCID : FAIL"
fi

echo "Reloading cpufreq driver module..."
TCID=bl-mod-reload01
insmod $MOD_LOCATION
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi

echo "Verifying cpufreq driver module loaded after reload..."
TCID=bl-mod-reload02
lsmod |grep arm_bl_cpufreq > /dev/null
ERR_CODE=$?
if [ $ERR_CODE -ne 0 ]; then
   echo "$TCID : FAIL"
else
   echo "$TCID : PASS"
fi


