package main

import (
	"fmt"
	"html/template"
	"log"
	"math"
	"net"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	activeWorkers int64
	activeGauge = prometheus.NewGaugeFunc(
		prometheus.GaugeOpts{
			Namespace: "bgdemo",
			Name:      "active_workers",
			Help:      "Number of active CPU-burning workers.",
		},
		func() float64 { return float64(atomic.LoadInt64(&activeWorkers)) },
	)
	httpReqs = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "bgdemo",
			Name:      "http_requests_total",
			Help:      "Total HTTP requests by path.",
		},
		[]string{"path"},
	)
)

func init() {
	prometheus.MustRegister(activeGauge, httpReqs)
}

var pageTmpl = template.Must(template.New("page").Parse(`<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Blue/Green + HPA/KEDA Demo (Gin)</title>
<style>
  :root{--blue:#e6f0ff;--green:#e6ffe6;}
  body{margin:0;padding:2rem;background: {{.BG}};font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Noto Sans KR",Arial,"Apple SD Gothic Neo","Malgun Gothic",sans-serif}
  .card{max-width:960px;margin:0 auto;background:#fff;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.08);padding:1.4rem}
  h1{margin:.2rem 0 1rem}
  code{background:#f6f6f6;padding:.15rem .4rem;border-radius:6px}
  .grid{display:grid;grid-template-columns:220px 1fr;gap:.6rem 1rem}
  .pill{display:inline-block;background:#eee;border-radius:999px;padding:.1rem .6rem}
  .muted{opacity:.75}
  .row{margin:.6rem 0}
  .btn{display:inline-block;padding:.5rem .8rem;border-radius:10px;background:#111;color:#fff;text-decoration:none}
  .btn:active{transform:translateY(1px)}
  ul{margin:.3rem 0 .8rem;padding-left:1.1rem}
</style>
</head>
<body>
<div class="card">
  <h1>Blue/Green + HPA/KEDA Demo (Gin)</h1>
  <p class="muted">쿼리 <code>?color=blue</code> 또는 <code>?color=green</code> 로 배경 전환</p>

  <div class="grid">
    <div><strong>현재 색상</strong></div><div><span class="pill">{{.Color}}</span></div>
    <div><strong>Pod IP</strong></div><div><code>{{.PodIP}}</code></div>
    <div><strong>Hostname</strong></div><div><code>{{.Hostname}}</code></div>
    <div><strong>Namespace</strong></div><div><code>{{.Namespace}}</code></div>
    <div><strong>Service Name</strong></div><div><code>{{.ServiceName}}</code></div>
    <div><strong>버전(Blue/Green)</strong></div><div><code>{{.Version}}</code></div>
    <div><strong>볼륨 경로</strong></div><div><code>{{.VolumePath}}</code></div>
    <div><strong>볼륨 용량</strong></div><div>Total: {{.VolumeTotal}} / Free: {{.VolumeFree}}</div>
    <div><strong>마운트 타입</strong></div><div><code>{{.FsType}}</code></div>
    <div><strong>볼륨 파일들</strong></div>
    <div>
      {{if .Files}}<ul>{{range .Files}}<li><code>{{.}}</code></li>{{end}}</ul>{{else}}<span class="muted">파일 없음</span>{{end}}
    </div>
  </div>

  <div class="row">
    <form action="/load" method="post">
      <input type="hidden" name="seconds" value="120"/>
      <input type="hidden" name="cpus" value="2"/>
      <button class="btn" type="submit">🚀 120초 × 2 vCPU 부하 (HPA/KEDA 테스트)</button>
    </form>
    <p class="muted">커스텀: <code>POST /load</code> with form/json <code>seconds</code>, <code>cpus</code> · 메트릭: <code>/metrics</code></p>
  </div>

  <div class="muted">Health: <code>/healthz</code> · Now: {{.Now}}</div>
</div>
</body>
</html>`))

func getenv(k, d string) string {
	v := strings.TrimSpace(os.Getenv(k))
	if v == "" {
		return d
	}
	return v
}

func firstNonLoopbackIPv4() string {
	ifaces, _ := net.Interfaces()
	for _, iface := range ifaces {
		addrs, _ := iface.Addrs()
		for _, a := range addrs {
			var ip net.IP
			switch v := a.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil || ip.IsLoopback() {
				continue
			}
			if v4 := ip.To4(); v4 != nil {
				return v4.String()
			}
		}
	}
	return ""
}

func statFs(path string) (total, free uint64, fstype string) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err == nil {
		total = st.Blocks * uint64(st.Bsize)
		free = st.Bavail * uint64(st.Bsize)
		fstype = fmt.Sprintf("0x%x", st.Type)
	}
	return
}

func humanize(b uint64) string {
	const u = 1024
	if b < u {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := uint64(u), 0
	for n := b / u; n >= u; n /= u {
		div *= u
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(b)/float64(div), "KMGTPE"[exp])
}

func listDir(path string, limit int) []string {
	ents, err := os.ReadDir(path)
	if err != nil {
		return nil
	}
	names := make([]string, 0, len(ents))
	for _, e := range ents {
		n := e.Name()
		if e.IsDir() { n += "/" }
		names = append(names, n)
	}
	sort.Strings(names)
	if limit > 0 && len(names) > limit {
		names = names[:limit]
	}
	return names
}

func burn(seconds int) {
	deadline := time.Now().Add(time.Duration(seconds) * time.Second)
	atomic.AddInt64(&activeWorkers, 1)
	defer atomic.AddInt64(&activeWorkers, -1)
	x := 0.0001
	for time.Now().Before(deadline) {
		x += math.Sqrt(x) * 1.0000001
		if x > 1e9 {
			x = 0.0001
		}
	}
}

func main() {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery(), func(c *gin.Context) {
		c.Next()
		httpReqs.WithLabelValues(c.FullPath()).Inc()
	})

	svcName := getenv("BG_SERVICE_NAME", "bg-web-svc")
	namespace := getenv("POD_NAMESPACE", "default")
	version := getenv("APP_VERSION", "blue")
	volumePath := getenv("VOLUME_PATH", "/data")
	port := getenv("PORT", "8080")

	// health
	r.GET("/healthz", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// metrics
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// load
	r.POST("/load", func(c *gin.Context) {
		type req struct {
			Seconds int `form:"seconds" json:"seconds"`
			Cpus    int `form:"cpus" json:"cpus"`
		}
		var in req
		_ = c.ShouldBind(&in)
		if in.Seconds <= 0 { in.Seconds = 60 }
		if in.Cpus <= 0 { in.Cpus = 1 }
		for i := 0; i < in.Cpus; i++ { go burn(in.Seconds) }
		c.JSON(200, gin.H{
			"status":  "started",
			"seconds": in.Seconds,
			"cpus":    in.Cpus,
			"hint":    "check HPA/KEDA scaling via metrics and top",
		})
	})

	// root
	r.GET("/", func(c *gin.Context) {
		color := strings.ToLower(c.Query("color"))
		if color != "blue" && color != "green" { color = version }
		bg := "#e6f0ff"
		if color == "green" { bg = "#e6ffe6" }

		podIP := getenv("POD_IP", "")
		if podIP == "" { podIP = firstNonLoopbackIPv4() }
		hostname, _ := os.Hostname()
		total, free, fstype := statFs(volumePath)
		files := listDir(volumePath, 50)

		data := map[string]any{
			"Color": color, "BG": bg, "PodIP": podIP, "Hostname": hostname,
			"Namespace": namespace, "ServiceName": svcName, "Version": version,
			"VolumePath": volumePath, "VolumeTotal": humanize(total), "VolumeFree": humanize(free),
			"FsType": fstype, "Files": files, "Now": time.Now().Format(time.RFC3339),
		}
		c.Status(200)
		_ = pageTmpl.Execute(c.Writer, data)
	})

	log.Printf("listening on :%s ...", port)
	_ = r.Run(":" + port)
}
