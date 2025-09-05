package main
import(
  "context"
  "database/sql"
  "fmt"
  "github.com/aws/aws-lambda-go/events"
  "github.com/aws/aws-lambda-go/lambda"
  _ "github.com/awslabs/aws-data-api-driver/go"
)
func handler(ctx context.Context, req events.APIGatewayProxyRequest)(events.APIGatewayProxyResponse, error){
  db, _ := sql.Open("rds-data-api", "aurora")
  defer db.Close()
  rows, _ := db.Query("select now()")
  defer rows.Close()
  var now string
  rows.Next(); rows.Scan(&now)
  return events.APIGatewayProxyResponse{StatusCode:200, Body: fmt.Sprintf("{"time":"%s"}", now)}, nil
}
func main(){ lambda.Start(handler) }
