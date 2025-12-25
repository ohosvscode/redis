/* pthread compatibility layer for musl libc
 * musl libc doesn't support pthread cancellation
 */

#ifndef PTHREAD_COMPAT_H
#define PTHREAD_COMPAT_H

#include <pthread.h>

/* Check if we're using musl libc (OpenHarmony uses musl) */
#ifdef __MUSL__
#define PTHREAD_CANCEL_DISABLED 1
#endif

/* Provide stub implementations for pthread cancellation functions */
#if defined(PTHREAD_CANCEL_DISABLED) || !defined(__GLIBC__)
static inline int pthread_setcancelstate(int state, int *oldstate) {
    (void)state;
    if (oldstate) *oldstate = PTHREAD_CANCEL_DISABLE;
    return 0;
}

static inline int pthread_setcanceltype(int type, int *oldtype) {
    (void)type;
    if (oldtype) *oldtype = PTHREAD_CANCEL_DEFERRED;
    return 0;
}

static inline int pthread_cancel(pthread_t thread) {
    (void)thread;
    return 0; /* Return success but do nothing */
}
#endif

#endif /* PTHREAD_COMPAT_H */

