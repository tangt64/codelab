package main
import (
  "context"
  "encoding/json"
  "github.com/aws/aws-lambda-go/events"
  "github.com/aws/aws-lambda-go/lambda"
)
type Note struct{ ID string `json:"id"`; Text string `json:"text"` }
func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
  switch req.HTTPMethod {
  case "GET":
    return events.APIGatewayProxyResponse{StatusCode:200, Body:`{"ok":true}`}, nil
  case "POST":
    var n Note; _ = json.Unmarshal([]byte(req.Body), &n)
    return events.APIGatewayProxyResponse{StatusCode:201, Body:req.Body}, nil
  }
  return events.APIGatewayProxyResponse{StatusCode:405, Body:"method not allowed"}, nil
}
func main(){ lambda.Start(handler) }
