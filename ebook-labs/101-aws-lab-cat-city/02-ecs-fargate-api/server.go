package main
import("fmt";"net/http";"os")
func main(){
  http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request){
    fmt.Fprintf(w, `{"status":"ok","host":"%s"}`, os.Getenv("HOSTNAME"))
  })
  http.HandleFunc("/api", func(w http.ResponseWriter, r *http.Request){
    fmt.Fprintln(w, `{"message":"hello from fargate"}`)
  })
  http.ListenAndServe(":8080", nil)
}
