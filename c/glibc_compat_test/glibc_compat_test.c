
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <gnu/libc-version.h>

int main() {
    void *ptr = malloc(100);
    printf("GLIBC version: %s\n", gnu_get_libc_version());
    printf("malloc usable size: %zu bytes\n", malloc_usable_size(ptr));
    printf("errno test (ENOMEM): %s\n", strerror(ENOMEM));
    printf("getpid: %d\n", getpid());
    free(ptr);
    return 0;
}
