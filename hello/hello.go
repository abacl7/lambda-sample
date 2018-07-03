package main

import (
  "context"

  "github.com/aws/aws-lambda-go/events"
  "github.com/aws/aws-lambda-go/lambda"
)

func hello(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
  return events.APIGatewayProxyResponse{Body: "Hello World!", StatusCode: 200}, nil
}

func main() {
  lambda.Start(hello)
}
