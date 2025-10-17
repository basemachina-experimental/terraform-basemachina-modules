package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Helper to get environment variable or fail test if unset
func mustGetenv(t *testing.T, key string) string {
	val := os.Getenv(key)
	if val == "" {
		t.Fatalf("Environment variable %s is required for this test", key)
	}
	return val
}

// Helper to get environment variable as slice
func getenvSlice(t *testing.T, key string) []string {
	val := mustGetenv(t, key)
	parts := strings.Split(val, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		t.Fatalf("Environment variable %s must not be an empty list", key)
	}
	return out
}

// TestECSFargateModule tests the ECS Fargate module deployment
func TestECSFargateModule(t *testing.T) {
	t.Parallel()

	// region from env or "ap-northeast-1" default
	awsRegion := os.Getenv("AWS_DEFAULT_REGION")
	if awsRegion == "" {
		awsRegion = "ap-northeast-1"
	}

	uniqueID := random.UniqueId()
	namePrefix := fmt.Sprintf("test-%s", uniqueID)

	// Required env vars for tf vars
	vpcID := mustGetenv(t, "TEST_VPC_ID")
	// privateSubnetIDs := getenvSlice(t, "TEST_PRIVATE_SUBNET_IDS")
	publicSubnetIDs := getenvSlice(t, "TEST_PUBLIC_SUBNET_IDS")
	tenantID := mustGetenv(t, "TEST_TENANT_ID")

	// Optional: certificate ARN (if not set, HTTP listener will be used)
	certificateArn := os.Getenv("TEST_CERTIFICATE_ARN")

	// Optional: desired count
	desiredCount := int64(1)
	if val := os.Getenv("TEST_DESIRED_COUNT"); val != "" {
		var n int64
		_, err := fmt.Sscanf(val, "%d", &n)
		if err == nil && n > 0 {
			desiredCount = n
		}
	}

	// AWS creds from env
	awsAccessKey := mustGetenv(t, "AWS_ACCESS_KEY_ID")
	awsSecretKey := mustGetenv(t, "AWS_SECRET_ACCESS_KEY")

	// Construct terraform vars
	tfVars := map[string]interface{}{
		"name_prefix": namePrefix,
		"vpc_id":      vpcID,
		// Use public subnets for tasks in test environment to allow ECR access without NAT Gateway
		"private_subnet_ids": publicSubnetIDs,
		"public_subnet_ids":  publicSubnetIDs,
		"tenant_id":          tenantID,
		"desired_count":      int(desiredCount),
		"assign_public_ip":   true, // Required for test environment without NAT Gateway
	}

	// Add certificate_arn only if provided (otherwise HTTP listener will be used)
	if certificateArn != "" {
		tfVars["certificate_arn"] = certificateArn
	}

	// Construct the terraform options with default retryable errors
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/aws-ecs-fargate",
		Vars:         tfVars,
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":        awsAccessKey,
			"AWS_SECRET_ACCESS_KEY":    awsSecretKey,
			"AWS_DEFAULT_REGION":       awsRegion,
			"AWS_DISABLE_EC2_METADATA": "true",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	albDNSName := terraform.Output(t, terraformOptions, "alb_dns_name")
	albArn := terraform.Output(t, terraformOptions, "alb_arn")
	albSecurityGroupID := terraform.Output(t, terraformOptions, "alb_security_group_id")
	ecsClusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	ecsClusterArn := terraform.Output(t, terraformOptions, "ecs_cluster_arn")
	ecsServiceName := terraform.Output(t, terraformOptions, "ecs_service_name")
	bridgeSecurityGroupID := terraform.Output(t, terraformOptions, "bridge_security_group_id")
	cloudwatchLogGroupName := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
	taskExecutionRoleArn := terraform.Output(t, terraformOptions, "task_execution_role_arn")
	taskRoleArn := terraform.Output(t, terraformOptions, "task_role_arn")

	assert.NotEmpty(t, albDNSName)
	assert.NotEmpty(t, albArn)
	assert.NotEmpty(t, albSecurityGroupID)
	assert.NotEmpty(t, ecsClusterName)
	assert.NotEmpty(t, ecsClusterArn)
	assert.NotEmpty(t, ecsServiceName)
	assert.NotEmpty(t, bridgeSecurityGroupID)
	assert.NotEmpty(t, cloudwatchLogGroupName)
	assert.NotEmpty(t, taskExecutionRoleArn)
	assert.NotEmpty(t, taskRoleArn)

	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(awsRegion),
	})
	require.NoError(t, err)

	ecsClient := ecs.New(sess)
	elbv2Client := elbv2.New(sess)

	maxRetries := 30
	timeBetweenRetries := 10 * time.Second

	// ECS Service check
	for i := 0; i < maxRetries; i++ {
		describeServicesInput := &ecs.DescribeServicesInput{
			Cluster:  aws.String(ecsClusterName),
			Services: []*string{aws.String(ecsServiceName)},
		}

		result, err := ecsClient.DescribeServices(describeServicesInput)
		if err != nil {
			t.Logf("Attempt %d/%d: Error getting ECS service info: %v", i+1, maxRetries, err)
			time.Sleep(timeBetweenRetries)
			continue
		}
		if len(result.Services) == 0 {
			t.Logf("Attempt %d/%d: ECS service not found", i+1, maxRetries)
			time.Sleep(timeBetweenRetries)
			continue
		}
		service := result.Services[0]
		runningTaskCount := *service.RunningCount

		t.Logf("Attempt %d/%d: ECS Service has %d running tasks (desired: %d)", i+1, maxRetries, runningTaskCount, desiredCount)

		if runningTaskCount == desiredCount {
			break
		}

		if i == maxRetries-1 {
			require.Equal(t, desiredCount, runningTaskCount, "ECS Service should have %d running tasks", desiredCount)
		}

		time.Sleep(timeBetweenRetries)
	}

	// ALB Target Group health check
	describeLoadBalancersInput := &elbv2.DescribeLoadBalancersInput{
		LoadBalancerArns: []*string{aws.String(albArn)},
	}
	lbResult, err := elbv2Client.DescribeLoadBalancers(describeLoadBalancersInput)
	require.NoError(t, err)
	require.NotEmpty(t, lbResult.LoadBalancers, "ALB should exist")

	describeTargetGroupsInput := &elbv2.DescribeTargetGroupsInput{
		LoadBalancerArn: aws.String(albArn),
	}
	tgResult, err := elbv2Client.DescribeTargetGroups(describeTargetGroupsInput)
	require.NoError(t, err)
	require.NotEmpty(t, tgResult.TargetGroups, "ALB should have at least one target group")

	targetGroupArn := *tgResult.TargetGroups[0].TargetGroupArn

	for i := 0; i < maxRetries; i++ {
		describeTargetHealthInput := &elbv2.DescribeTargetHealthInput{
			TargetGroupArn: aws.String(targetGroupArn),
		}

		healthResult, err := elbv2Client.DescribeTargetHealth(describeTargetHealthInput)
		if err != nil {
			t.Logf("Attempt %d/%d: Error getting target health: %v", i+1, maxRetries, err)
			time.Sleep(timeBetweenRetries)
			continue
		}

		healthyCount := int64(0)
		for _, targetHealth := range healthResult.TargetHealthDescriptions {
			if targetHealth.TargetHealth != nil && *targetHealth.TargetHealth.State == "healthy" {
				healthyCount++
			}
		}

		t.Logf("Attempt %d/%d: Target group has %d healthy targets (desired: %d)", i+1, maxRetries, healthyCount, desiredCount)

		if healthyCount == desiredCount {
			assert.Equal(t, desiredCount, healthyCount, "Target group should have %d healthy targets", desiredCount)
			break
		}

		if i == maxRetries-1 {
			require.Equal(t, desiredCount, healthyCount, "Target group should have %d healthy targets after waiting", desiredCount)
		}

		time.Sleep(timeBetweenRetries)
	}

	t.Log("All tests passed successfully!")
}
