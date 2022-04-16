package test

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"

	grunt_aws "github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	grunt_random "github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestS3Delete(t *testing.T) {
	t.Skip()
	awsRegion := "ap-southeast-2"
	bucket := "cloudfront-test-qobm1x"
	testObjectName := "test.html"
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(awsRegion))
	if err != nil {
		fmt.Println("configuration error, " + err.Error())
		os.Exit(1)
	}

	client := s3.NewFromConfig(cfg)

	deleteInput := &s3.DeleteObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(testObjectName),
	}

	_, err = client.DeleteObject(context.TODO(), deleteInput)
	if err != nil {
		fmt.Println("delete error, " + err.Error())
		os.Exit(1)
	}

	headInput := &s3.HeadObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(testObjectName),
	}
	maxWaitTime, _ := time.ParseDuration("5m")
	waiter := s3.NewObjectNotExistsWaiter(client)
	waiter.Wait(context.TODO(), headInput, maxWaitTime)
}

func TestS3Origin(t *testing.T) {
	// t.Skip()
	awsRegion := grunt_aws.GetRandomStableRegion(t, nil, nil)

	uniqueID := strings.ToLower(grunt_random.UniqueId())
	bucket := fmt.Sprintf("cloudfront-test-%s", uniqueID)
	testDocStr := fmt.Sprintf("<!DOCTYPE html><title>cloudfront test</title><body>%s</body>", uniqueID)
	testDomain := "spaceytest.xyz"
	testObjectName := "test.html"
	testUrlStruct := url.URL{
		Scheme: "https",
		Host:   testDomain,
		Path:   testObjectName,
	}
	testUrlStr := testUrlStruct.String()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"aws_region":     awsRegion,
			"bucket":         bucket,
			"primary_domain": testDomain,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(awsRegion))
	if err != nil {
		fmt.Println("configuration error, " + err.Error())
		terraform.Destroy(t, terraformOptions)
		os.Exit(1)
	}

	client := s3.NewFromConfig(cfg)

	uploadInput := &s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(testObjectName),
		Body:   strings.NewReader(testDocStr),
	}

	_, err = client.PutObject(context.TODO(), uploadInput)
	if err != nil {
		fmt.Println("upload error, " + err.Error())
		terraform.Destroy(t, terraformOptions)
		os.Exit(1)
	}

	tlsConfig := tls.Config{}
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	// Verify that we get back a 200 OK with the contents of our test HTML
	http_helper.HttpGetWithRetry(t, testUrlStr, &tlsConfig, 200, testDocStr, maxRetries, timeBetweenRetries)

	deleteInput := &s3.DeleteObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(testObjectName),
	}

	_, err = client.DeleteObject(context.TODO(), deleteInput)
	if err != nil {
		fmt.Println("delete error, " + err.Error())
		terraform.Destroy(t, terraformOptions)
		os.Exit(1)
	}

	// DeleteObject returns before the test file is totally gone
	// terraform needs the file deleted before the bucket can be destroyed
	headInput := &s3.HeadObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(testObjectName),
	}
	maxWaitTime, _ := time.ParseDuration("5m")
	waiter := s3.NewObjectNotExistsWaiter(client)
	waiter.Wait(context.TODO(), headInput, maxWaitTime)
}
