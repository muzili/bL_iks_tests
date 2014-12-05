DESTDIR ?= /
TESTS=boot-a7/boot-a7.sh data-corruption/data-corruption.sh disk-io-stress-switcher/disk-io-stress-switcher.sh \
 cache-coherency-switcher/cache-coherency-switcher.sh mem-stress-switcher/mem-stress-switcher.sh \
 boot-a15/boot-a15.sh data-corruption-switcher/data-corruption-switcher.sh \
 basic/switcher-tests/fastswitch.sh basic/switcher-tests/100_switches.sh basic/switcher-tests/switcher-tests.sh \
 basic/switcher-tests/reswitch.sh basic/switcher-tests/try_rmmod.sh basic/run-bl-basic-tests.sh \
 basic/governor.sh basic/module.sh basic/switch.sh bl-agitator/bl-agitator \
 vfp-ffmpeg-switcher/vfp-ffmpeg-switcher.sh vfp-ffmpeg/vfp-ffmpeg.sh \
 cluster-status/cluster-status.sh basic/switcher-tests/switcher_enable_disable.sh \
 basic/switcher-tests/switcher_off_hotplug_cpu.sh cpu_freq_vs_cluster_freq/cpu_freq_cope_on_cluster_freq.sh \
 cpu_freq_vs_cluster_freq/cpu_freq_vs_cluster_freq.sh \
 perf-count-events/perf-disk-io-stress-switcher.sh perf-count-events/perf-mem-stress-switcher.sh \
 interactive-governor-test.sh run_stress_switcher_tests.sh affinity_tools/affinity_tools 

DATA=data-corruption/images/boxes.ppm
INPUT=vfp-ffmpeg/inputfiles/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG
LOG_FILE=cpu_freq_vs_cluster_freq/inputfiles/cpu_freq_cope_on_cluster_freq_output_org.log

all:
	make CFLAGS=$(CFLAGS) -C bl-agitator
	make CFLAGS=$(CFLAGS) -C affinity_tools

clean:
	make -C bl-agitator clean
	make -C affinity_tools clean

install:
	mkdir -p $(DESTDIR)/usr/bin $(DESTDIR)/usr/share/testdata
	cp $(TESTS) $(DESTDIR)/usr/bin
	cp $(DATA) $(DESTDIR)/usr/share/testdata
	cp $(INPUT) $(DESTDIR)/usr/share/testdata
	cp $(LOG_FILE) $(DESTDIR)/usr/share/testdata
