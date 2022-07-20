package test

import (
	"crypto/tls"
	"fmt"
	"net/url"
	"strings"
	"testing"
	"time"

	grunt_aws "github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	grunt_random "github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestALBOrigin(t *testing.T) {
	t.Skip()
	awsRegion := grunt_aws.GetRandomStableRegion(t, nil, nil)

	uniqueID := strings.ToLower(grunt_random.UniqueId())
	testDocStr := fmt.Sprintf("<!DOCTYPE html><title>cloudfront test</title><body>%s</body>", uniqueID)
	cfDomain := "spaceytest.xyz"
	originDomain := "spaceytest-origin.xyz"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./alb-origin",
		Vars: map[string]interface{}{
			"aws_region":     awsRegion,
			"primary_domain": cfDomain,
			"origin_domain":  originDomain,
			"html_text":      testDocStr,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	tlsConfig := tls.Config{}
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	// Verify that we get back a 200 OK with the contents of our test HTML
	http_helper.HttpGetWithRetry(t, cfDomain, &tlsConfig, 200, testDocStr, maxRetries, timeBetweenRetries)
}

func TestS3Origin(t *testing.T) {
	awsRegion := grunt_aws.GetRandomStableRegion(t, nil, nil)

	uniqueID := strings.ToLower(grunt_random.UniqueId())
	bucket := fmt.Sprintf("cloudfront-test-%s", uniqueID)
	testDocStr := fmt.Sprintf("<!DOCTYPE html><title>cloudfront test</title><body>%s</body>", uniqueID)
	testObjectName := "test.html"

	aDomain := "spaceytest.xyz"
	aDomainTestUrlStruct := url.URL{
		Scheme: "https",
		Host:   aDomain,
		Path:   testObjectName,
	}
	aDomainTestUrl := aDomainTestUrlStruct.String()

	cnameDomain := fmt.Sprintf("www.%s", aDomain)
	cnameDomainTestUrlStruct := url.URL{
		Scheme: "https",
		Host:   cnameDomain,
		Path:   testObjectName,
	}
	cnameDomainTestUrl := cnameDomainTestUrlStruct.String()

	domains := map[string]interface{}{
		"primary":   aDomain,
		"alternate": []string{cnameDomain},
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./s3-origin",
		Vars: map[string]interface{}{
			"aws_region":          awsRegion,
			"bucket":              bucket,
			"test_object_key":     testObjectName,
			"test_object_content": testDocStr,
			"domains":             domains,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	tlsConfig := tls.Config{}
	maxRetries := 5
	timeBetweenRetries := 5 * time.Second
	// Verify that we get back a 200 OK with the contents of our test HTML
	http_helper.HttpGetWithRetry(t, aDomainTestUrl, &tlsConfig, 200, testDocStr, maxRetries, timeBetweenRetries)
	http_helper.HttpGetWithRetry(t, cnameDomainTestUrl, &tlsConfig, 200, testDocStr, maxRetries, timeBetweenRetries)
}
