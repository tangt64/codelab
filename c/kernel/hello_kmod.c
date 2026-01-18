#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_init(void) {
    pr_info("kmod: hello! current pid=%d\n", current->pid);
    return 0;
}

static void __exit hello_exit(void) {
    pr_info("kmod: bye!\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("demo");
MODULE_DESCRIPTION("Kernel internal API demo (pr_info/current)");
