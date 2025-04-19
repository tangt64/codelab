#include <stdio.h>
#include "utils.h"
#include "hello.h"

int main() {
    printf("Hello from glibc printf()\n");

    print_internal();
    print_hello();

    return 0;
}
