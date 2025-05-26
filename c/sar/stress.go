
package main

import (
    "io/ioutil"
    "math"
    "net/http"
    "os"
    "time"
)

func cpuStress() {
    for {
        _ = math.Sqrt(123456.789)
    }
}

func memStress() {
    var mem [][]byte
    for {
        mem = append(mem, make([]byte, 1024*1024))
        time.Sleep(100 * time.Millisecond)
    }
}

func diskStress() {
    for {
        ioutil.WriteFile("/tmp/stress.txt", []byte("0"), 0644)
        os.Remove("/tmp/stress.txt")
    }
}

func netStress() {
    for {
        http.Get("http://example.com")
        time.Sleep(500 * time.Millisecond)
    }
}

func main() {
    go cpuStress()
    go memStress()
    go diskStress()
    go netStress()
    select {}
}
