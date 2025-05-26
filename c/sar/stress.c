
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <pthread.h>
#include <string.h>
#include <curl/curl.h>

void *cpu_stress(void *arg) {
    while (1) double x = sqrt(12345.6789);
    return NULL;
}

void *mem_stress(void *arg) {
    while (1) {
        char *ptr = malloc(1024 * 1024);
        if (ptr) memset(ptr, 0, 1024 * 1024);
        usleep(100000);
    }
    return NULL;
}

void *disk_stress(void *arg) {
    while (1) {
        FILE *f = fopen("/tmp/stress.txt", "w");
        if (f) {
            for (int i = 0; i < 1024 * 1024; i++) fputc('0', f);
            fclose(f);
            remove("/tmp/stress.txt");
        }
    }
    return NULL;
}

void *net_stress(void *arg) {
    CURL *curl;
    while (1) {
        curl = curl_easy_init();
        if(curl) {
            curl_easy_setopt(curl, CURLOPT_URL, "http://example.com");
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, 2L);
            curl_easy_perform(curl);
            curl_easy_cleanup(curl);
        }
        sleep(1);
    }
    return NULL;
}

int main() {
    pthread_t t1, t2, t3, t4;
    pthread_create(&t1, NULL, cpu_stress, NULL);
    pthread_create(&t2, NULL, mem_stress, NULL);
    pthread_create(&t3, NULL, disk_stress, NULL);
    pthread_create(&t4, NULL, net_stress, NULL);
    pthread_join(t1, NULL);
    return 0;
}
