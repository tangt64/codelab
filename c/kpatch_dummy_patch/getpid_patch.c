#include <linux/syscalls.h>
#include <linux/kernel.h>

asmlinkage long sys_getpid(void)
{
    printk(KERN_INFO "🔧 Patched sys_getpid() called!\n");
    return 99999;
}
