/*
go build -o swapload swapload.go
swapload -percent 60 -duration 120
swapload -percent 70 -duration 180 -step 20
free -h
vmstat 1
sar -r 1
top

*/
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

var (
	percent  = flag.Int("percent", 50, "memory usage percent (0-100)")
	duration = flag.Int("duration", 60, "duration in seconds")
	stepMB   = flag.Int("step", 50, "allocation step in MB")
)

func getTotalMemoryKB() int64 {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "MemTotal:") {
			fields := strings.Fields(line)
			val, _ := strconv.ParseInt(fields[1], 10, 64)
			return val
		}
	}
	panic("MemTotal not found")
}

func main() {
	flag.Parse()

	totalMemKB := getTotalMemoryKB()
	targetKB := totalMemKB * int64(*percent) / 100
	targetBytes := targetKB * 1024

	fmt.Printf("[*] Total Memory  : %d MB\n", totalMemKB/1024)
	fmt.Printf("[*] Target Usage : %d %% (%d MB)\n", *percent, targetKB/1024)
	fmt.Printf("[*] Duration     : %d seconds\n", *duration)

	var blocks [][]byte
	allocated := int64(0)

	stepBytes := int64(*stepMB) * 1024 * 1024

	fmt.Println("[*] Allocating memory...")
	for allocated < targetBytes {
		block := make([]byte, stepBytes)
		// Touch memory to prevent lazy allocation
		for i := 0; i < len(block); i += 4096 {
			block[i] = 1
		}
		blocks = append(blocks, block)
		allocated += stepBytes

		fmt.Printf("  allocated: %d MB\r", allocated/1024/1024)
		time.Sleep(500 * time.Millisecond)
	}

	fmt.Println("\n[*] Allocation complete. Holding memory...")

	time.Sleep(time.Duration(*duration) * time.Second)

	fmt.Println("[*] Releasing memory...")
	blocks = nil
	time.Sleep(2 * time.Second)

	fmt.Println("[*] Done.")
}
