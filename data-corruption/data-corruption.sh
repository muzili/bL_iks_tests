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
# Author: Avik Sil <avik.sil@linaro.org>

# Assumes package libjpeg-turbo-progs is installed

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <Inputfile (BMP|PPM)> [iterations]"
    exit 1
fi

echo
echo "*** Data Corruption Test ***"

if [ ! -e "$1" ]; then
    echo "File $1 does not exist!"
    exit 1
fi

if [ -n "$2" ]; then
    if [ $(echo "$2" | grep -E "^[0-9]+$") ]; then
        iterations=$2
    else
        echo "<iterations> must be a valid number; setting it to 1"
        iterations=1
    fi
else
    iterations=1
fi

Q=75
filename=`echo $1 | sed 's/\(.*\)\..*/\1/'`
suffix_gray="_GRAY_Q$Q.jpg"
suffix_420="_420_Q$Q.jpg"
suffix_422="_422_Q$Q.jpg"
suffix_444="_444_Q$Q.jpg"
encoded_filename_gray=$filename$suffix_gray
encoded_filename_420=$filename$suffix_420
encoded_filename_422=$filename$suffix_422
encoded_filename_444=$filename$suffix_444

tjbench $1 $Q -rgb -quiet scale 1/2
MD5SUM_ORIG_GRAY=`md5sum $encoded_filename_gray | cut -f 1 -d ' '`
MD5SUM_ORIG_420=`md5sum $encoded_filename_420 | cut -f 1 -d ' '`
MD5SUM_ORIG_422=`md5sum $encoded_filename_422 | cut -f 1 -d ' '`
MD5SUM_ORIG_444=`md5sum $encoded_filename_444 | cut -f 1 -d ' '`

i=1
while true;
do
    echo
    echo "Iteration $i/$iterations:"

    tjbench $1 $Q -rgb -quiet scale 1/2
    MD5SUM_GRAY=`md5sum $encoded_filename_gray | cut -f 1 -d ' '`
    MD5SUM_420=`md5sum $encoded_filename_420 | cut -f 1 -d ' '`
    MD5SUM_422=`md5sum $encoded_filename_422 | cut -f 1 -d ' '`
    MD5SUM_444=`md5sum $encoded_filename_444 | cut -f 1 -d ' '`

    if [ $MD5SUM_GRAY = $MD5SUM_ORIG_GRAY ]; then
        echo "Data corruption test: MD5SUM_GRAY: PASS"
    else
        echo "Data corruption test: MD5SUM_GRAY: FAIL"
	exit 1
    fi
    if [ $MD5SUM_420 = $MD5SUM_ORIG_420 ]; then
        echo "Data corruption test: MD5SUM_420: PASS"
    else
        echo "Data corruption test: MD5SUM_420: FAIL"
	exit 1
    fi
    if [ $MD5SUM_422 = $MD5SUM_ORIG_422 ]; then
        echo "Data corruption test: MD5SUM_422: PASS"
    else
        echo "Data corruption test: MD5SUM_422: FAIL"
	exit 1
    fi
    if [ $MD5SUM_444 = $MD5SUM_ORIG_444 ]; then
        echo "Data corruption test: MD5SUM_444: PASS"
    else
        echo "Data corruption test: MD5SUM_444: FAIL"
	exit 1
    fi

    i=$((i+1))
    if [ "$i" -gt "$iterations" ]; then
        echo
        echo "*** Data Corruption Test completed successfully"
        exit 0
    fi
done

