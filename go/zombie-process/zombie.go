/*
go build -o zombie-go zombie.go
zombie-go
*/

// zombie.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
)

func main() {
	// 자식으로 매우 빨리 끝나는 프로세스 실행
	cmd := exec.Command("/bin/sh", "-c", "echo '[child] exiting'; exit 0")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		fmt.Println("Start error:", err)
		return
	}

	fmt.Printf("[parent] pid=%d, child pid=%d\n", os.Getpid(), cmd.Process.Pid)
	fmt.Println("[parent] NOT calling Wait(). Sleep 60s so you can observe zombie.")
	time.Sleep(60 * time.Second)

	// 일부러 cmd.Wait()를 호출하지 않음
}
