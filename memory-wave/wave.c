#if defined(__linux__)
// https://linux.die.net/man/3/malloc_usable_size
#include <malloc.h>
size_t portable_ish_malloced_size(const void *p) {
    return malloc_usable_size((void*)p);
}
#elif defined(__APPLE__)
// https://www.unix.com/man-page/osx/3/malloc_size/
#include <malloc/malloc.h>
size_t portable_ish_malloced_size(const void *p) {
    return malloc_size(p);
}
#elif defined(_WIN32)
// https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/msize
#include <malloc.h>
size_t portable_ish_malloced_size(const void *p) {
    return _msize((void *)p);
}
#else
#error "oops, I don't know this system"
#endif

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <pthread.h>
#include <time.h>
#include <math.h>
#include <string.h>
#include <unistd.h>

#define BILLION 1000000000.0
#define TICK_TIME_S 5


struct arg_struct {
    long n;
    int skip;
    const char* type;
    struct timespec ts;
    struct timespec *runtime;
    struct timespec *sleeptime;
};

long MiBtoB(long MiB) {
    return MiB * 1 << 20;
}

long BtoMiB(long B) {
    return B / (1 << 20);
}

long BtoKiB(long B) {
    return B / (1 << 10);
}

pthread_t child_thread_id = NULL;
pthread_t baseline_thread_id = NULL;

static volatile sig_atomic_t should_run = 1;
static volatile sig_atomic_t signaled_child = 0;

static void sig_handler(int sig)
{
    if (pthread_equal(child_thread_id,pthread_self()) || 
        pthread_equal(baseline_thread_id,pthread_self())) {
        puts("Child thread exiting...");
        pthread_exit(0);
    } else {
        printf("Stopping on signal %u.\n", sig);
        if ( child_thread_id != NULL && !signaled_child ) {
            signaled_child = true;
            pthread_kill(baseline_thread_id, sig);
            pthread_kill(child_thread_id, sig);
            pthread_join(child_thread_id, NULL);
            pthread_join(baseline_thread_id, NULL);
            puts("Exited.");
        }
        puts("Done.");
        exit(0);
    }
}

void allocate_memory(const char* type, long n, int skip, struct timespec ts,
                     struct timespec *runtime, struct timespec *sleeptime) {

    child_thread_id = pthread_self();
    struct timespec start, end;
    clock_gettime(CLOCK_REALTIME, &start);

	char* ptr;
    struct timespec request = ts;
    struct timespec remaining = ts;

	// Dynamically allocate memory using malloc()
	ptr = (char*)calloc(n, sizeof(char));

	// Check if the memory has been successfully allocated by malloc or not
	if (ptr == NULL) {
		puts("Memory not allocated.");
		exit(EXIT_FAILURE);
	}

    // Memory has been successfully allocated
    //size_t true_length = portable_ish_malloced_size(ptr);
    
    //BtoKiB(true_length));

    // Populate the elements of the array
    printf("Filling %s array...", type);
    for (long i = 0; i < n; i=i+skip) {
        ptr[i] = (int)(i/2)%26 + 'a';
    }
    puts("Done.");

    if (strcmp(type,"periodic")==0) {
        clock_gettime(CLOCK_REALTIME, &end);
        double time_spent = (end.tv_sec - start.tv_sec) +
                            (end.tv_nsec - start.tv_nsec) / BILLION;

        double interval = ts.tv_sec + ts.tv_nsec / BILLION;
        double sleep_interval = interval - time_spent;
        double intpart, fractpart;
        fractpart = modf(time_spent, &intpart);
        runtime->tv_sec = (long)intpart;
        runtime->tv_nsec = (long)(fractpart * BILLION);

        fractpart = modf(sleep_interval, &intpart);
        sleeptime->tv_sec = (long)intpart;
        sleeptime->tv_nsec = (long)(fractpart * BILLION);

        request.tv_sec = sleeptime->tv_sec;
        request.tv_nsec = sleeptime->tv_nsec;
        remaining.tv_sec = sleeptime->tv_sec;
        remaining.tv_nsec = sleeptime->tv_nsec;


        nanosleep(&request, &remaining);
        free(ptr);
        pthread_exit(0);
    } else {
        while (should_run) {
            sleep(60);
        }
    }
}

void *allocate_memory_thread(void *arguments)
{
    struct arg_struct *args = (struct arg_struct *)arguments;
    allocate_memory(args->type, args -> n, args -> skip, args -> ts, args -> runtime, args -> sleeptime);
    return NULL;
}

// // function to return a constant amount of memory
// long calculate_allocation_const(long variable, int tick, int period) {
//     return variable;
// }

// calculate_allocation_cos returns a sinusoidal amount of variable based on
// tick/period radians.
long calculate_allocation_cos(long variable, int tick, int period) {
    double scale_value;
    scale_value = 0.5 + (-0.5 * cos ( (double)tick / (double)period * 2.0 * M_PI ) );
    variable = (long)((double)variable * scale_value );
    return variable;
}

// calculate_allocation is eventually going to be the indirection point to the
// specific implementation (const, linear, cos, random)
long calculate_allocation(long variable, int tick, int period) {
    return calculate_allocation_cos(variable, tick, period);
}


int main(int argc, char **argv)
{
    long n, v;
    int period, tick_index;

    // enable the signal handler for SIGINT
    struct sigaction act;
    act.sa_handler = sig_handler;
    sigaction(SIGINT, &act, NULL);
    sigaction(SIGTERM, &act, NULL);

    // prevent stdout buffering
    setbuf(stdout, NULL);


    if (argc < 4 ||argc > 6) {
        puts("ERR: baseline MiB, max varying MiB, and period in 5s ticks required.");
        printf("USAGE:  %s «baseline_bytes» «max_varying_bytes» «period»\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    n = MiBtoB(atol(argv[1]));
    v = MiBtoB(atol(argv[2]));
    period = atoi(argv[3]);
    tick_index = 0;

    int skip = 1;
    if (argc>=5) {
       skip = atoi(argv[4]);
       if (skip < 1) { 
           skip = 1;
        }
    }

    time_t tick_time = TICK_TIME_S;
    if (argc==6) {
        tick_time = atol(argv[5]);
    }

    struct timespec ts = {tick_time,0};

    struct arg_struct baseline_args, thread_args;
    puts("Parsed Parameters");
    puts("------------------------------");
    printf("  baseline: %luMiB\n", BtoMiB(n));
    printf("  variable: %luMiB\n", BtoMiB(v));
    printf("    period: %u\n", period);
    printf("      skip: %u\n", skip);
    printf(" tick_time: %lu\n", tick_time);

    //start baseline memory thread
    baseline_args.n = n;
    baseline_args.skip = skip;
    baseline_args.type = "baseline";
    pthread_t baseline_thread_id;
    // allocate the baseline memory in a thread and let it hang out.
    pthread_create(&baseline_thread_id, NULL, allocate_memory_thread, (void *)&baseline_args);

    while (should_run) {
        long variable = calculate_allocation(v, tick_index, period);
        struct timespec runtime, sleeptime;
        thread_args.n = variable;
        thread_args.skip = skip;
        thread_args.type = "periodic";
        thread_args.ts = ts;
        thread_args.runtime = &runtime;
        thread_args.sleeptime = &sleeptime;
 
        printf("{phase:\"start\", period: %u, tick: %u, baseline: %lu, variable: %lu, total: %luMiB}\n", period, tick_index, n, variable, BtoMiB(n+variable));
        pthread_t thread_id;
        pthread_create(&thread_id, NULL, allocate_memory_thread, (void *)&thread_args);
        pthread_join(thread_id, NULL);
        child_thread_id = NULL;
        printf("{phase:\"end\", period: %u, tick: %u, runtime: %f, sleeptime: %f}\n", period, tick_index, runtime.tv_sec + runtime.tv_nsec/BILLION, sleeptime.tv_sec + sleeptime.tv_nsec/BILLION);

        tick_index = (tick_index+1) % period;
    }

	return 0;
}
