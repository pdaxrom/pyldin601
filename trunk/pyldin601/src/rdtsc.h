#ifndef __RDTSC_H__
#define __RDTSC_H__

#include <time.h>

#if defined(__i386__)

static inline unsigned long long rdtsc(void)
{
    unsigned long long int x;
    __asm__ __volatile__("rdtsc" : "=A" (x));
    return x;
}
#elif defined(__x86_64__DISABLED)


static inline unsigned long long rdtsc(void)
{
  unsigned hi, lo;
  __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
  return ( (unsigned long long)lo)|( ((unsigned long long)hi)<<32 );
}

#elif defined(__powerpc__)

static inline unsigned long long rdtsc(void)
{
  unsigned long long int result=0;
  unsigned long int upper, lower,tmp;
  __asm__ volatile(
                "0:                  \n"
                "\tmftbu   %0           \n"
                "\tmftb    %1           \n"
                "\tmftbu   %2           \n"
                "\tcmpw    %2,%0        \n"
                "\tbne     0b         \n"
                : "=r"(upper),"=r"(lower),"=r"(tmp)
                );
  result = upper;
  result = result<<32;
  result = result|lower;

  return(result);
}

#else

static inline unsigned long long rdtsc(void)
{
    struct timespec tp;
#ifdef __ARM_ARCH_7A__DISABLED
    uint32_t pmccntr;
    uint32_t pmuseren;
    uint32_t pmcntenset;
    static int no_mrc = 0;

    // Read the user mode perf monitor counter access permissions.
    asm volatile ("mrc p15, 0, %0, c9, c14, 0" : "=r" (pmuseren));
    if (pmuseren & 1) {  // Allows reading perfmon counters for user mode code.
      asm volatile ("mrc p15, 0, %0, c9, c12, 1" : "=r" (pmcntenset));
      if (pmcntenset & 0x80000000ul) {  // Is it counting?
        asm volatile ("mrc p15, 0, %0, c9, c13, 0" : "=r" (pmccntr));
        // The counter is set up to count every 64th cycle
        return (uint64_t)pmccntr * 64;  // Should optimize to << 6
      }
    } else if (!no_mrc) {
	no_mrc = 1;
	SDL_Log("No tsc :( Use non optimized clock counter...");
    }
#endif

    clock_gettime (CLOCK_MONOTONIC_RAW, &tp);
    return (uint64_t)tp.tv_sec * 1e9 + tp.tv_nsec;
}

#endif

#endif
