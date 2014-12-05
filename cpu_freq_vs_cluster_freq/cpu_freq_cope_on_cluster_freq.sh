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
# Modified-by: Nicolas Pitre <nicolas.pitre@linaro.org>
#

GOVERNOR=userspace
# set userspace governor
set_governor()
{
  for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  do echo $GOVERNOR > $file
  done
  sleep 1
}
# set lowest frequency everywhere
set_lowest_freq()
{
  for cpufreq in /sys/devices/system/cpu/cpu*/cpufreq
  do cat $cpufreq/scaling_min_freq > $cpufreq/scaling_setspeed
  done
}

# now cycle each CPU in turn and see the effect on others
cycle_all_cpus()
{
  for cpu in /sys/devices/system/cpu/cpu*/
  do if [ -f $cpu/cpufreq/cpuinfo_cur_freq ]
     then orig_freq=$(cat $cpu/cpufreq/cpuinfo_cur_freq)
          for freq in $(cat $cpu/cpufreq/scaling_available_frequencies)
          do echo $freq > $cpu/cpufreq/scaling_setspeed
             usleep 500000
             echo -ne "$(basename $cpu)=$freq:"
             dump_current_cpu_freqs
          done
          echo $orig_freq > $cpu/cpufreq/scaling_setspeed
     fi
  done
}

dump_current_cpu_freqs()
{
  for file in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
  do echo -ne "\t$(cat $file)"
  done
  echo
}

set_governor
set_lowest_freq
cycle_all_cpus
