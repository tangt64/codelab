// kernel_api_test.c
#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/syscall.h>

int main(void) {
    struct utsname u;
    if (uname(&u) != 0) {
        perror("uname");
        return 1;
    }

    pid_t pid = getpid();                 // glibc wrapper -> syscall
    long tid = syscall(SYS_gettid);       // direct syscall

    printf("uname.sysname : %s\n", u.sysname);
    printf("uname.release : %s\n", u.release);
    printf("getpid        : %d\n", pid);
    printf("gettid(syscall): %ld\n", tid);

    // 실패 케이스로 errno 보기: 존재하지 않는 PID에 signal 보내보기
    int r = syscall(SYS_kill, 999999, 0);
    if (r != 0) {
        printf("kill(999999,0) failed as expected: errno=%d (%s)\n",
               errno, strerror(errno));
    }
    return 0;
}
