PRODUCT_COPY_FILES += \
    test/linaro/biglittle/core/boot-a15/boot-a15.sh:system/bin/boot-a15.sh \
    test/linaro/biglittle/core/boot-a7/boot-a7.sh:system/bin/boot-a7.sh \
    test/linaro/biglittle/core/disk-io-stress-switcher/disk-io-stress-switcher.sh:system/bin/disk-io-stress-switcher.sh \
    test/linaro/biglittle/core/mem-stress-switcher/mem-stress-switcher.sh:system/bin/mem-stress-switcher.sh \
    test/linaro/biglittle/core/data-corruption-switcher/data-corruption-switcher.sh:system/bin/data-corruption-switcher.sh \
    test/linaro/biglittle/core/data-corruption/data-corruption.sh:system/bin/data-corruption.sh \
    test/linaro/biglittle/core/data-corruption/images/boxes.ppm:data/boxes/boxes.ppm \
    test/linaro/biglittle/core/basic/module.sh:system/bin/module.sh \
    test/linaro/biglittle/core/basic/governor.sh:system/bin/governor.sh \
    test/linaro/biglittle/core/basic/switch.sh:system/bin/switch.sh \
    test/linaro/biglittle/core/basic/run-bl-basic-tests.sh:system/bin/run-bl-basic-tests.sh \
    test/linaro/biglittle/core/cache-coherency-switcher/cache-coherency-switcher.sh:system/bin/cache-coherency-switcher.sh \
    test/linaro/biglittle/core/basic/switcher-tests/100_switches.sh:system/bin/100_switches.sh \
    test/linaro/biglittle/core/basic/switcher-tests/fastswitch.sh:system/bin/fastswitch.sh \
    test/linaro/biglittle/core/basic/switcher-tests/reswitch.sh:system/bin/reswitch.sh \
    test/linaro/biglittle/core/basic/switcher-tests/switcher-tests.sh:system/bin/switcher-tests.sh \
    test/linaro/biglittle/core/basic/switcher-tests/try_rmmod.sh:system/bin/try_rmmod.sh \
    test/linaro/biglittle/core/basic/switcher-tests/switcher_enable_disable.sh:system/bin/switcher_enable_disable.sh \
    test/linaro/biglittle/core/basic/switcher-tests/switcher_off_hotplug_cpu.sh:system/bin/switcher_off_hotplug_cpu.sh \
    test/linaro/biglittle/core/vfp-ffmpeg-switcher/vfp-ffmpeg-switcher.sh:system/bin/vfp-ffmpeg-switcher.sh \
    test/linaro/biglittle/core/vfp-ffmpeg/vfp-ffmpeg.sh:system/bin/vfp-ffmpeg.sh \
    test/linaro/biglittle/core/vfp-ffmpeg/inputfiles/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG:data/boxes/big_buck_bunny_VORBIS_2Channel_48k_128K_short.OGG \
    test/linaro/biglittle/core/cluster-status/cluster-status.sh:system/bin/cluster-status.sh \
    test/linaro/biglittle/core/interactive-governor-test.sh:system/bin/interactive-governor-test.sh \
    test/linaro/biglittle/core/run_stress_switcher_tests.sh:system/bin/run_stress_switcher_tests.sh \
    test/linaro/biglittle/core/cpu_freq_vs_cluster_freq/cpu_freq_cope_on_cluster_freq.sh:system/bin/cpu_freq_cope_on_cluster_freq.sh \
    test/linaro/biglittle/core/cpu_freq_vs_cluster_freq/cpu_freq_vs_cluster_freq.sh:system/bin/cpu_freq_vs_cluster_freq.sh \
    test/linaro/biglittle/core/cpu_freq_vs_cluster_freq/inputfiles/cpu_freq_cope_on_cluster_freq_output_org.log:data/boxes/cpu_freq_cope_on_cluster_freq_output_org.log \
    test/linaro/biglittle/core/perf-count-events/perf-disk-io-stress-switcher.sh:system/bin/perf-disk-io-stress-switcher.sh \
    test/linaro/biglittle/core/perf-count-events/perf-mem-stress-switcher.sh:system/bin/perf-mem-stress-switcher.sh

PRODUCT_PACKAGES += affinity_tools
