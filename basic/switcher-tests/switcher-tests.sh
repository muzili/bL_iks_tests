tests_dir=$(dirname $0)

MODEL=`cat /proc/device-tree/model`

echo "===== 100_switches.sh ====="
${tests_dir}/100_switches.sh

echo "===== reswitch.sh ====="
${tests_dir}/reswitch.sh

echo "===== fastswitch.sh ====="
${tests_dir}/fastswitch.sh

# For RTSM platform
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	echo "===== try_rmmod.sh ====="
	${tests_dir}/try_rmmod.sh
fi

# For TC2 platform
if [ "$MODEL" = "V2P-CA15_CA7" ]; then
	echo "===== switcher_enable_disable.sh ====="
	${tests_dir}/switcher_enable_disable.sh
	echo "===== switcher_off_hotplug_cpu.sh ====="
	${tests_dir}/switcher_off_hotplug_cpu.sh
fi
