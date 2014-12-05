/*
 * bl-agitator.c
 *
 * big.LITTLE tool to interface with kernel's cpufreq.
 *
 * - sysfs helpers were grabbed from cpufrequtils-008
 *   (with minor cosmetic tweaks). That code belongs to:
 *   Dominik Brodowski <linux@dominikbrodowski.de>
 *
 * Licensed under the terms of the GNU General Public License version 2.
 *
 * Complain to: Omar Ramirez Luna <omar.luna@linaro.org>
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define SYSFS_CPU	"/sys/devices/system/cpu/"
#define MAX_LINE	255
#define LINE_LEN	10
#define PATH_MAX_LEN	255

#define DEFAULT_LIMIT	1000			/* msecs for random switching */

static int verbose;

#define dbg(err, fmt ...)						\
do {									\
	if (err || verbose)						\
		printf(fmt);						\
} while (0)								\

struct bl_properties {
	int cpu_max;
	int cpuid;
	int used;
	unsigned long big_freq;
	unsigned long little_freq;

	pthread_t thread;
};

struct bl_properties *cpu_props;

static int ind_switch;
static char *frequency;
static char *governor;
static char *switch_period;
static char *seed;
static char *limit;
static int info;
static int threaded;
static int sync_transition;

static struct timespec start;
static int used_cnt;
static int transition_cnt;

pthread_mutex_t mutex;
pthread_cond_t count;

/* cpufrequtils-008 */

/* helper function to read file from /sys into given buffer */
/* fname is a relative path under "cpuX/cpufreq" dir */
unsigned int sysfs_read_file(unsigned int cpu, const char *fname, char *buf, size_t buflen)
{
	char path[PATH_MAX_LEN];
	int fd;
	ssize_t numread;

	snprintf(path, sizeof(path), SYSFS_CPU "cpu%u/cpufreq/%s", cpu, fname);

	if ((fd = open(path, O_RDONLY)) == -1) {
		dbg(1, "failed to open %s, errno %d\n", path, errno);
		return fd;
	}

	numread = read(fd, buf, buflen - 1);
	if (numread < 1) {
		close(fd);
		dbg(1, "failed to read %s, errno %d\n", fname, errno);
		return -EIO;
	}

	buf[numread] = '\0';
	close(fd);

	return numread;
}

/* helper function to write a new value to a /sys file */
/* fname is a relative path under "cpuX/cpufreq" dir */
unsigned int sysfs_write_file(unsigned int cpu, const char *fname, const char *value, size_t len)
{
	char path[PATH_MAX_LEN];
	int fd;
	ssize_t numwrite;

	snprintf(path, sizeof(path), SYSFS_CPU "cpu%u/cpufreq/%s", cpu, fname);

	if ((fd = open(path, O_WRONLY)) == -1) {
		dbg(1, "failed to open %s, errno %d\n", path, errno);
		return fd;
	}

	numwrite = write(fd, value, len);
	if (numwrite < 1) {
		close(fd);
		dbg(1, "failed to write %s, errno %d\n", fname, errno);
		return numwrite;
	}

	close(fd);

	return numwrite;
}

static unsigned int count_cpus(void)
{
	FILE *fp;
	char value[LINE_LEN];
	unsigned int ret = 0;
	unsigned int cpunr = 0;

	fp = fopen("/proc/stat", "r");
	if(!fp) {
		printf("Couldn't count the number of CPUs (%s: err %d), assuming 1\n", "/proc/stat", errno);
		return 1;
	}

	while (!feof(fp)) {
		if (!fgets(value, LINE_LEN, fp))
			continue;
		value[LINE_LEN - 1] = '\0';
		if (strlen(value) < (LINE_LEN - 2))
			continue;
		if (strstr(value, "cpu "))
			continue;
		if (sscanf(value, "cpu%d ", &cpunr) != 1)
			continue;
		if (cpunr > ret)
			ret = cpunr;
	}
	fclose(fp);

	/* cpu count starts from 0, on error return 1 (UP) */
	return ret + 1;
}


void thread_transition_barrier()
{
	pthread_mutex_lock(&mutex);

	transition_cnt++;

	if (transition_cnt != used_cnt) {
		pthread_cond_wait(&count, &mutex);
	} else {
		transition_cnt = 0;
		pthread_cond_broadcast(&count);
	}

	pthread_mutex_unlock(&mutex);
}

/* big.LITTLE helpers */

static char *_bl_name(struct bl_properties blp, unsigned long freq)
{
	if (freq == blp.big_freq)
		return "big";

	if (freq == blp.little_freq)
		return "LITTLE";

	return "unknown";
}

static int set_affinity(struct bl_properties *blp)
{
	cpu_set_t cpuset;

	CPU_ZERO(&cpuset);
	CPU_SET(blp->cpuid, &cpuset);

	/*
	 * Android doesn't support pthread_setaffinity_np, and glibc doesn't
	 * have a wrapper for gettid(), alternatively we could use
	 * syscall(__NR_gettid) for both...
	 */
#ifdef ANDROID
	return sched_setaffinity(gettid(), sizeof(cpuset), &cpuset);
#else
	return pthread_setaffinity_np(blp->thread, sizeof(cpuset), &cpuset);
#endif
}

static int is_cpu_used(int id)
{
	if (ind_switch)
		return cpu_props[id].used;
	else
		return 1;
}

struct bl_properties *get_cpu_props(void)
{
	if (!cpu_props) {
		printf("error cpu_props is null\n");
		return NULL;
	}

	return cpu_props;
}

/* big.LITTLE sysfs functions */

static int bl_prepare_info(struct bl_properties *blp)
{
	char line[MAX_LINE];
	int i;
	int err;
	int cpu_max = count_cpus();

	cpu_props = malloc(sizeof(*cpu_props) * cpu_max);
	if (!cpu_props)
		return -ENOMEM;

	memset(cpu_props, 0, sizeof(*cpu_props) * cpu_max);

	printf("***bl-agitator***\nCPU count: %d\n", cpu_max);
	for (i = 0; i < cpu_max; i++) {
		cpu_props[i].cpu_max = cpu_max;
		cpu_props[i].cpuid = i;

		/* Get _big_ frequency */
		err = sysfs_read_file(0, "cpuinfo_max_freq", line, sizeof(line));
		if (err < 0)
			goto err;
		cpu_props[i].big_freq = strtoul(line, NULL, 0);

		/* Get _LITTLE_ frequency */
		err = sysfs_read_file(0, "cpuinfo_min_freq", line, sizeof(line));
		if (err < 0)
			goto err;
		cpu_props[i].little_freq = strtoul(line, NULL, 0);

		printf("CPU%d:    big freq %lu    LITTLE freq %lu\n",
			i, cpu_props[i].big_freq, cpu_props[i].little_freq);
	}

	return 0;

err:
	free(cpu_props);
	return err;
}

static int bl_check_cpu_state(struct bl_properties blp)
{
	char line[MAX_LINE];
	unsigned long curr_freq;
	int err;

	err = sysfs_read_file(blp.cpuid, "cpuinfo_cur_freq", line, sizeof(line));
	curr_freq = strtoul(line, NULL, 0);
	printf("cpu%d cpuinfo_cur_freq %lu [%s]\n",
			blp.cpuid, curr_freq, _bl_name(blp, curr_freq));
	if (err < 0)
		return err;

	return 0;
}

static int bl_set_frequency(struct bl_properties blp, char *frequency)
{
	char line[MAX_LINE], curr[MAX_LINE];
	unsigned long target_freq, curr_freq;
	int err;

	if (strcmp("big", frequency) == 0) {
		target_freq = blp.big_freq;
		snprintf(line, MAX_LINE, "%lu", blp.big_freq);
	} else if(strcmp("little", frequency) == 0) {
		target_freq = blp.little_freq;
		snprintf(line, MAX_LINE, "%lu", blp.little_freq);
	} else {
		printf("unknown target frequency\n");
		return -EINVAL;
	}

	sysfs_write_file(blp.cpuid, "scaling_setspeed", line, sizeof(line));
	/* DONE: consider cpuinfo_transition_latency before checking */
	usleep(50000);
	sysfs_read_file(blp.cpuid, "cpuinfo_cur_freq", curr, sizeof(curr));
	curr_freq = strtoul(curr, NULL, 0);

	err = curr_freq == target_freq ? 0 : 1;
	dbg(err, "cpu%d scaling_setspeed target %lu current %lu... %s\n",
		blp.cpuid, target_freq, curr_freq, !err ? "OK" : "FAIL");

	if (err)
		return -EIO;

	return 0;
}

static int bl_set_governor(struct bl_properties blp, char *governor)
{
	char line[MAX_LINE], curr[MAX_LINE];
	int len, err;

	len = strlen(governor);
	if (len > 20)
		return -EINVAL;
	strncpy(line, governor, len + 1);

	sysfs_write_file(blp.cpuid, "scaling_governor", line, 20);
	sysfs_read_file(blp.cpuid, "scaling_governor", curr, 20);
	err = strncmp(line, curr, len) || curr[len] != '\n';
	dbg(err, "cpu%d scaling_governor set to %s ... %s\n",
				blp.cpuid, line, !err ? "OK" : "FAIL");

	if (err)
		return -EIO;

	return 0;
}

static int _bl_single_cpu_switch(struct bl_properties blp, unsigned long time)
{
	if (bl_set_frequency(blp, "big"))
		return -EIO;
	usleep(time * 1000);

	if (sync_transition)
		thread_transition_barrier();

	if (bl_set_frequency(blp, "little"))
		return -EIO;
	usleep(time * 1000);

	if (sync_transition)
		thread_transition_barrier();

	return 0;
}

static int _bl_multi_cpu_switch(unsigned long time)
{
	struct bl_properties *props = get_cpu_props();
	int cpu_max = props->cpu_max;
	int i;

	for (i = 0; i < cpu_max; i++) {
		if (!is_cpu_used(i))
			continue;

		if (bl_set_frequency(props[i], "big"))
				return -EIO;
		usleep(time * 1000);
	}

	for (i = 0; i < cpu_max; i++) {
		if (!is_cpu_used(i))
			continue;

		if (bl_set_frequency(props[i], "little"))
				return -EIO;
		usleep(time * 1000);
	}

	return 0;
}

static int _bl_periodic_switch(struct bl_properties blp, char *switch_period)
{
	unsigned long time;
	unsigned long iter = 0;
	int err;

	time = strtoul(switch_period, NULL, 0);
	if (!time)
		return -EINVAL;

	printf("Periodic switcher time %lu\n", time);

	if (threaded) {
		err = bl_set_governor(blp, "userspace");
		if (err)
			return err;

		while (1) {
			if (_bl_single_cpu_switch(blp, time)) {
				dbg(1, "error on iteration %lu period %lu\n", iter, time);
				return -EIO;
			}
			iter++;
		}
	} else {
		struct bl_properties *props = get_cpu_props();
		int cpu_max = props->cpu_max;
		int i;

		for (i = 0; i < cpu_max; i++) {
			if (!is_cpu_used(i))
				continue;

			err = bl_set_governor(props[i], "userspace");
			if (err)
				return err;
		}

		while (1) {
			if (_bl_multi_cpu_switch(time)) {
				dbg(1, "error on iteration %lu period %lu\n", iter, time);
				return -EIO;
			}
			iter++;
		}
	}

	return 0;
}

void *bl_periodic_switch(void *cpu_prop)
{
	struct bl_properties *blp = cpu_prop;
	long err;

	if (threaded) {
		err = set_affinity(blp);
		if (err)
			return (void *)err;
	}

	err = _bl_periodic_switch(*blp, switch_period);

	return (void *)err;
}

static int _bl_random_switch(struct bl_properties blp, char *seed, char *limit)
{
	unsigned long iter = 0, t, seedn, lim;
	int err;

	seedn = strtoul(seed, NULL, 0);
	if (seedn)
		srand(seedn);
	else
		srand(time(NULL));

	if (!limit)
		lim = DEFAULT_LIMIT;
	else
		lim = strtoul(limit, NULL, 0);

	if (!lim || lim > RAND_MAX)
		lim = RAND_MAX;

	printf("Random switcher seed %lu limit %lu\n", seedn, lim);

	if (threaded) {
		err = bl_set_governor(blp, "userspace");
		if (err)
			return err;

		while (1) {
			t = (double)rand() / RAND_MAX * (lim - 1) + 1;
			if (_bl_single_cpu_switch(blp, t)) {
				dbg(1, "error on iteration %lu period %lu\n", iter, t);
				return -EIO;
			}
			iter++;
		}
	} else {
		struct bl_properties *props = get_cpu_props();
		int cpu_max = props->cpu_max;
		int i;

		for (i = 0; i < cpu_max; i++) {
			if (!is_cpu_used(i))
				continue;

			err = bl_set_governor(props[i], "userspace");
			if (err)
				return err;
		}

		while (1) {
			t = (double)rand() / RAND_MAX * (lim - 1) + 1;
			if (_bl_multi_cpu_switch(t)) {
				dbg(1, "error on iteration %lu period %lu\n", iter, t);
				return -EIO;
			}
			iter++;
		}
	}

	return 0;
}

void *bl_random_switch(void *cpu_prop)
{
	struct bl_properties *blp = cpu_prop;
	long err;

	if (threaded) {
		err = set_affinity(blp);
		if (err)
			return (void *)err;
	}

	err = _bl_random_switch(*blp, seed, limit);

	return (void *)err;
}

void print_elapsed_time()
{
	struct timespec end, elapsed;
	long int msec, sec, min, hour;

	clock_gettime(CLOCK_MONOTONIC, &end);

	elapsed.tv_sec = end.tv_sec - start.tv_sec;
	elapsed.tv_nsec = end.tv_nsec - start.tv_nsec;

	if (elapsed.tv_nsec < 0) {
		msec = (1000000000 + end.tv_sec - start.tv_sec) / 1000000;
		elapsed.tv_sec -= 1;
	} else {
		msec = elapsed.tv_nsec / 1000000;
	}

	hour = elapsed.tv_sec / 3600;
	min = (elapsed.tv_sec % 3600) / 60;
	sec = elapsed.tv_sec % 60;

	printf("Time elapsed: %ld:%02ld:%02ld.%03ld\n", hour, min, sec, msec);
}

void sigaction_handler(int sig)
{
	print_elapsed_time();
	dbg(1, "Terminated because of SIG %d\n", sig);
	exit(0);
}

static struct option long_opts[] = {
	{"cpu",		required_argument,	0,	'c'},
	{"freq",	required_argument,	0,	'f'},
	{"governor",	required_argument,	0,	'g'},
	{"info",	no_argument,		0,	'i'},
	{"switch",	required_argument,	0,	's'},
	{"rand",	required_argument,	0,	'r'},
	{"limit",	required_argument,	0,	'l'},
	{"thread",	no_argument,		0,	'n'},
	{"sync-thread",	no_argument,		0,	'S'},
	{"verbose",	no_argument,		0,	'v'},
	{0, 0, 0, 0 }
};

void usage()
{
	printf("usage: ./bl-agitator [-v] [-i] [-f <big|little>] [-g <governor>] [-s <msecs>]\n");
	printf("Options:\n");
	printf(" -i, --info\t\t\tCheck which cluster is running [big|little]\n");
	printf(" -c  --cpu <num>\t\tOperate on this cpu, this option can be specified multiple times\n");
	printf(" -f, --freq\t\t\tSet a cluster to the desired frequency\n");
	printf(" -g, --governor <governor>\tChange to desired governor\n");
	printf(" -s, --switch <time>\t\tbig.LITTLE switching using 'time' as interval (in msecs)\n");
	printf(" -r, --rand <seed>\t\tRandom seed for periodic time switch, 0 will use time()\n");
	printf(" -l, --limit <num>\t\tInterval limit for random number generation\n");
	printf(" -n  --thread\t\t\tSet threaded mode for random or periodic switching\n");
	printf("\t\tOn threaded mode:\n");
	printf("\t\t -S, --single-sync\t\t\tSequential half transition (e.g.: big->barrier->little->barrier\n");
	printf(" -v, --verbose\t\t\tVerbose mode\n");
	printf(" -h, --help\t\t\tthis help screen\n");
	exit (1);
}

static int run_commands()
{
	int i, ret;
	int max_cpu = count_cpus();

	if (info) {
		for (i = 0; i < max_cpu; i++) {
			if (!is_cpu_used(i))
				continue;
			ret = bl_check_cpu_state(cpu_props[i]);
			if (ret)
				return ret;
		}
	}

	if (governor) {
		for (i = 0; i < max_cpu; i++) {
			if (!is_cpu_used(i))
				continue;

			ret = bl_set_governor(cpu_props[i], governor);
			if (ret)
				return ret;
		}
	}

	if (frequency) {
		for (i = 0; i < max_cpu; i++) {
			if (!is_cpu_used(i))
				continue;

			ret = bl_set_frequency(cpu_props[i], frequency);
			if (ret)
				return ret;
		}
	}

	if (seed) {
		if (threaded) {
			for (i = 0; i < max_cpu; i++) {
				if (!is_cpu_used(i))
					continue;

				pthread_create(&cpu_props[i].thread, NULL, bl_random_switch, &cpu_props[i]);
			}
		} else {
			/* Cast err_ptr */
			ret = (long)bl_random_switch(get_cpu_props());
			if (ret)
				return ret;
		}
	}

	if (switch_period) {
		if (threaded) {
			for (i = 0; i < max_cpu; i++) {
				if (!is_cpu_used(i))
					continue;

				pthread_create(&cpu_props[i].thread, NULL, bl_periodic_switch, &cpu_props[i]);
			}
		} else {
			/* Cast err_ptr */
			ret = (long)bl_periodic_switch(get_cpu_props());
			if (ret)
				return ret;
		}
	}

	if (threaded) {
		for (i = 0; i < max_cpu; i++) {
			if (!is_cpu_used(i))
				continue;

			pthread_join(cpu_props[i].thread, NULL);
		}
	}

	return 0;
}

int main(int argc, char **argv)
{
	int c, max_cpu;
	struct bl_properties blp;
	struct sigaction sigact;

	memset(&sigact, 0, sizeof(sigact));
	sigemptyset(&sigact.sa_mask);
	sigact.sa_flags = 0;
	sigact.sa_handler = &sigaction_handler;

	sigaction(SIGINT, &sigact, 0);
	sigaction(SIGTERM, &sigact, 0);

	if (bl_prepare_info(&blp))
		goto err;

	max_cpu = count_cpus();

	while (1) {
		int opt_id = 0;

		c = getopt_long(argc, argv, "hic:f:g:s:r:l:nSv", long_opts, &opt_id);
		if (c == -1)
			break;

		switch (c) {
		case 'i':
			info = 1;
			break;
		case 'c':
			ind_switch = 1;
			int cpu = atoi(optarg);
			if (cpu >= max_cpu || cpu < 0) {
				dbg(1, "Unknown CPU%d\n", cpu);
				goto free;
			}
			cpu_props[cpu].used = 1;
			used_cnt++;
			break;
		case 'f':
			frequency = optarg;
			break;
		case 'g':
			governor = optarg;
			break;
		case 's':
			if (seed) {
				usage();
				goto free;
			}
			switch_period = optarg;
			break;
		case 'n':
			threaded = 1;
			break;
		case 'S':
			sync_transition = 1;
			break;
		case 'v':
			verbose = 1;
			break;
		case 'r':
			if (switch_period) {
				usage();
				goto free;
			}
			seed = optarg;
			break;
		case 'l':
			limit = optarg;
			break;
		case 'h':
		default:
			usage();
			break;
		}
	}

	if (!ind_switch)
		used_cnt = max_cpu;

	if (threaded && !(seed || switch_period)) {
		usage();
		goto free;
	}

	if (!threaded && sync_transition) {
		usage();
		goto free;
	}

	clock_gettime(CLOCK_MONOTONIC, &start);

	if (run_commands())
		goto exit;

	print_elapsed_time();
	exit(0);

exit:
	print_elapsed_time();
free:
	free(cpu_props);
err:
	exit(1);
}
