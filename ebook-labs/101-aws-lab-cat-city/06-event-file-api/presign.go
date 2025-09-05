package main
import(
  "context"
  "fmt"
  "time"
  "github.com/aws/aws-lambda-go/events"
  "github.com/aws/aws-lambda-go/lambda"
  "github.com/aws/aws-sdk-go-v2/aws"
  "github.com/aws/aws-sdk-go-v2/config"
  "github.com/aws/aws-sdk-go-v2/feature/s3/presign"
  "github.com/aws/aws-sdk-go-v2/service/s3"
)
func handler(ctx context.Context, req events.APIGatewayProxyRequest)(events.APIGatewayProxyResponse, error){
  cfg,_ := config.LoadDefaultConfig(ctx)
  client := s3.NewFromConfig(cfg)
  ps := presign.NewPresignClient(client)
  url,_ := ps.PresignPutObject(ctx,&s3.PutObjectInput{
    Bucket: aws.String("mybucket"), Key: aws.String("upload/test.txt")},s3.WithPresignExpires(15*time.Minute))
  return events.APIGatewayProxyResponse{StatusCode:200, Body: fmt.Sprintf("{"url":"%s"}", url.URL)}, nil
}
func main(){ lambda.Start(handler) }
