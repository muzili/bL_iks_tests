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
# Modified-by: Naresh Kamboju <naresh.kamboju@linaro.org>
#

usage()
{
    echo "usage: $0 <mmc image> "
}

if [ -z "$1" ]; then
        usage
        exit
fi

# mount the system partition
mkdir /tmp/mmc/
sudo mount -t ext4 -o loop,offset=138412032 $1 /tmp/mmc/

# Copy the scripts and prebuilts 
find . -iname "*.sh" -execdir sudo cp '{}' /tmp/mmc/bin \;
sudo cp android-prebuilts/* /tmp/mmc/bin/

# unmount the system partition
sudo umount -f /tmp/mmc/

# mount the data partition
sudo mount -t ext4 -o loop,offset=943734784 $1 /tmp/mmc/

# Copy the image
mkdir /tmp/mmc/boxes/
sudo cp data-corruption/images/boxes.ppm /tmp/mmc/boxes/
sudo cp vfp-ffmpeg/inputfiles/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG /tmp/mmc/boxes/

# unmount the data partition
sudo umount -f /tmp/mmc/
rm -r /tmp/mmc/
