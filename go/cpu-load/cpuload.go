/*
go build -o cpu-load-go cpu_load.go
pu-load-go 50 60
*/

package main

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

func busyWait(duration time.Duration) {
	start := time.Now()
	for time.Since(start) < duration {
	}
}

func main() {
	if len(os.Args) != 3 {
		fmt.Printf("Usage: %s <cpu_load_percent> <duration_sec>\n", os.Args[0])
		return
	}

	load, _ := strconv.Atoi(os.Args[1])
	seconds, _ := strconv.Atoi(os.Args[2])

	if load < 0 || load > 100 || seconds <= 0 {
		fmt.Println("Invalid arguments")
		return
	}

	busyTime := time.Duration(load) * 10 * time.Millisecond
	idleTime := time.Duration(100-load) * 10 * time.Millisecond

	end := time.Now().Add(time.Duration(seconds) * time.Second)

	for time.Now().Before(end) {
		if busyTime > 0 {
			busyWait(busyTime)
		}
		if idleTime > 0 {
			time.Sleep(idleTime)
		}
	}
}
