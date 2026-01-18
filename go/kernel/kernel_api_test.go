// kernel_api_test.go
package main

import (
	"fmt"
	"os"
	"runtime"
	"syscall"
)

func main() {
	fmt.Println("GOOS/GOARCH:", runtime.GOOS, runtime.GOARCH)

	// 1) 커널 정보: uname (syscall.Uname)
	var u syscall.Utsname
	if err := syscall.Uname(&u); err != nil {
		fmt.Println("Uname error:", err)
		os.Exit(1)
	}
	fmt.Println("uname.sysname:", charsToString(u.Sysname[:]))
	fmt.Println("uname.release:", charsToString(u.Release[:]))

	// 2) PID (syscall)
	fmt.Println("getpid:", os.Getpid())

	// 3) 실패 예시: 없는 PID에 signal 0
	err := syscall.Kill(999999, 0)
	if err != nil {
		fmt.Println("kill(999999,0) failed as expected:", err)
	}
}

func charsToString(ca []int8) string {
	b := make([]byte, 0, len(ca))
	for _, c := range ca {
		if c == 0 {
			break
		}
		b = append(b, byte(c))
	}
	return string(b)
}
