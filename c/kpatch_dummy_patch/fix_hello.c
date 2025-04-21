#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/kpatch.h>

int patched_function(void) {
    pr_info("✅ [kpatch dummy] patched_function() is active!\n");
    return 42;
}

KPATCH_MODULE
