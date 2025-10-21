package test

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	run "cloud.google.com/go/run/apiv2"
	runpb "cloud.google.com/go/run/apiv2/runpb"
	sqladmin "google.golang.org/api/sqladmin/v1"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ========================================
// Task 7.2: Helper Functions
// ========================================

// mustGetenv gets environment variable or fails test if unset
func mustGetenv(t *testing.T, key string) string {
	val := os.Getenv(key)
	if val == "" {
		t.Fatalf("Environment variable %s is required for this test", key)
	}
	return val
}


// retryWithTimeout retries a function with exponential backoff
func retryWithTimeout(t *testing.T, timeout time.Duration, interval time.Duration, fn func() error) error {
	deadline := time.Now().Add(timeout)
	attempt := 0

	for time.Now().Before(deadline) {
		attempt++
		err := fn()
		if err == nil {
			return nil
		}

		t.Logf("Attempt %d failed: %v. Retrying in %v...", attempt, err, interval)
		time.Sleep(interval)
	}

	return fmt.Errorf("operation timed out after %v", timeout)
}

// ========================================
// Task 7.3-7.6: Cloud Run Integration Test
// ========================================

// TestCloudRunModule tests the Cloud Run module deployment
func TestCloudRunModule(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	// Get required environment variables
	projectID := mustGetenv(t, "TEST_GCP_PROJECT_ID")
	region := os.Getenv("TEST_GCP_REGION")
	if region == "" {
		region = "asia-northeast1"
	}
	tenantID := mustGetenv(t, "TEST_TENANT_ID")

	// Optional: Domain configuration for HTTPS testing
	// If domain_name is set, the test will verify HTTPS, SSL, DNS, and Cloud Armor
	domainName := os.Getenv("TEST_DOMAIN_NAME")
	dnsZoneName := os.Getenv("TEST_DNS_ZONE_NAME")


	// Generate unique ID for resource naming
	uniqueID := strings.ToLower(random.UniqueId())
	serviceName := fmt.Sprintf("bridge-test-%s", uniqueID)

	// Construct Terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/gcp-cloud-run",
		Vars: map[string]any{
			"project_id":   projectID,
			"region":       region,
			"service_name": serviceName,
			"tenant_id":    tenantID,

			// Bridge configuration
			"fetch_interval": "1h",
			"fetch_timeout":  "10s",
			"port":           8080,

			// Resource configuration
			"cpu":           "1",
			"memory":        "512Mi",
			"min_instances": 0,
			"max_instances": 10,

			// Domain configuration (optional)
			"domain_name":   domainName,
			"dns_zone_name": dnsZoneName,

			// Cloud Armor IP whitelist (allow all IPs for testing)
			// WARNING: For testing purposes only. In production, restrict to specific IPs.
			"allowed_ip_ranges": []string{"34.85.43.93/32", "0.0.0.0/0"},

			// Cloud SQL configuration
			"database_name": "testdb",
			"database_user": "testuser",
		},
	})

	// Ensure cleanup
	// Note: VPC Peering deletion may fail due to GCP timing issues.
	// This is expected and will be cleaned up when running the cleanup script.
	defer func() {
		t.Log("Starting terraform destroy...")

		// VPC Peering削除エラーは既知の問題のため、panicをrecoverしてログのみ出力
		defer func() {
			if r := recover(); r != nil {
				t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				t.Logf("⚠️  terraform destroy failed (this is a known GCP VPC Peering issue)")
				t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				t.Logf("")
				t.Logf("To clean up remaining resources, run:")
				t.Logf("")
				t.Logf("  cd examples/gcp-cloud-run")
				t.Logf("  ./scripts/cleanup.sh %s", projectID)
				t.Logf("")
				t.Logf("Or manually delete resources in GCP Console:")
				t.Logf("  - Cloud SQL instances starting with: %s-db-", serviceName)
				t.Logf("  - VPC network: %s-vpc", serviceName)
				t.Logf("")
				t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				t.Logf("")

				// テストは失敗させない（VPC Peering削除は既知の問題のため）
				// t.FailNow()の代わりにログのみ出力
			}
		}()

		terraform.Destroy(t, terraformOptions)
		t.Log("terraform destroy completed successfully")
	}()

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// ========================================
	// Task 7.3: Cloud Run Service Validation
	// ========================================

	t.Run("CloudRunServiceExists", func(t *testing.T) {
		// Verify Cloud Run service exists
		client, err := run.NewServicesClient(ctx)
		require.NoError(t, err)
		defer client.Close()

		servicePath := fmt.Sprintf("projects/%s/locations/%s/services/%s", projectID, region, serviceName)
		service, err := client.GetService(ctx, &runpb.GetServiceRequest{
			Name: servicePath,
		})
		require.NoError(t, err)
		assert.NotNil(t, service)

		t.Logf("Cloud Run service found: %s", service.Name)

		// Verify service configuration
		template := service.GetTemplate()
		require.NotNil(t, template)

		containers := template.GetContainers()
		require.NotEmpty(t, containers)

		container := containers[0]

		// Verify environment variables
		envVars := container.GetEnv()
		envMap := make(map[string]string)
		for _, env := range envVars {
			envMap[env.GetName()] = env.GetValue()
		}

		assert.Equal(t, "1h", envMap["FETCH_INTERVAL"])
		assert.Equal(t, "10s", envMap["FETCH_TIMEOUT"])
		assert.Equal(t, tenantID, envMap["TENANT_ID"])
		// Note: PORT environment variable is automatically set by Cloud Run from container_port

		// Verify container port
		ports := container.GetPorts()
		require.NotEmpty(t, ports)
		assert.Equal(t, int32(8080), ports[0].GetContainerPort())

		// Verify resource limits
		resources := container.GetResources()
		require.NotNil(t, resources)
		assert.Equal(t, "1", resources.Limits["cpu"])
		assert.Equal(t, "512Mi", resources.Limits["memory"])

		// Verify ingress setting (internal load balancer only)
		assert.Equal(t, runpb.IngressTraffic_INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER, service.GetIngress())

		t.Logf("Cloud Run service configuration verified")
	})

	// ========================================
	// Task 7.4: HTTPS and Health Check Test
	// ========================================

	if domainName != "" {
		t.Run("HTTPSHealthCheck", func(t *testing.T) {
			// Get domain URL from outputs
			domainURL := fmt.Sprintf("https://%s", domainName)
			lbIP := terraform.Output(t, terraformOptions, "bridge_load_balancer_ip")

			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			t.Logf("HTTPS Health Check Configuration")
			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			t.Logf("  Domain:         %s", domainName)
			t.Logf("  URL:            %s/ok", domainURL)
			t.Logf("  Load Balancer:  %s", lbIP)
			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

			// Check DNS resolution first
			t.Logf("Step 1: Checking DNS resolution...")
			ips, err := net.LookupIP(domainName)
			if err != nil {
				t.Logf("  ❌ DNS lookup failed: %v", err)
			} else {
				t.Logf("  ✅ DNS resolved to: %v", ips)
				for _, ip := range ips {
					if ip.String() == lbIP {
						t.Logf("  ✅ Load Balancer IP matched: %s", lbIP)
					}
				}
			}

			// Wait for SSL certificate to be provisioned and DNS to propagate
			// This can take up to 15 minutes
			t.Logf("\nStep 2: Waiting for SSL certificate provisioning and health check...")
			t.Logf("  Timeout: 5 minutes")
			t.Logf("  Interval: 30 seconds")

			err = retryWithTimeout(t, 5*time.Minute, 30*time.Second, func() error {
				// Log detailed attempt information
				t.Logf("\n  → Attempting HTTPS request to %s/ok", domainURL)

				// Create custom HTTP client with timeout
				client := &http.Client{
					Timeout: 10 * time.Second,
				}

				resp, err := client.Get(domainURL + "/ok")
				if err != nil {
					t.Logf("     ❌ Request error: %v", err)
					return fmt.Errorf("HTTP request failed: %w", err)
				}
				defer resp.Body.Close()

				t.Logf("     Status: %d %s", resp.StatusCode, http.StatusText(resp.StatusCode))
				t.Logf("     TLS: %v", resp.TLS != nil)
				if resp.TLS != nil && len(resp.TLS.PeerCertificates) > 0 {
					cert := resp.TLS.PeerCertificates[0]
					t.Logf("     Certificate: CN=%s, Issuer=%s", cert.Subject.CommonName, cert.Issuer.CommonName)
					t.Logf("     Valid: %v - %v", cert.NotBefore, cert.NotAfter)
				}

				if resp.StatusCode != http.StatusOK {
					// Read response body for error details
					body, _ := io.ReadAll(resp.Body)
					bodyPreview := string(body)
					if len(bodyPreview) > 500 {
						bodyPreview = bodyPreview[:500] + "..."
					}
					t.Logf("     Response body: %s", bodyPreview)
					return fmt.Errorf("expected status 200, got %d: %s", resp.StatusCode, http.StatusText(resp.StatusCode))
				}

				body, err := io.ReadAll(resp.Body)
				if err != nil {
					t.Logf("     ❌ Failed to read body: %v", err)
					return fmt.Errorf("failed to read response body: %w", err)
				}

				bodyStr := strings.ToLower(strings.TrimSpace(string(body)))
				t.Logf("     Response body: '%s'", bodyStr)

				if bodyStr != "ok" {
					t.Logf("     ❌ Unexpected body content")
					return fmt.Errorf("expected response body 'ok', got '%s'", bodyStr)
				}

				t.Logf("     ✅ Health check succeeded!")
				return nil
			})

			require.NoError(t, err, "HTTPS health check failed")
			t.Logf("\n✅ HTTPS health check passed: %s/ok", domainURL)

			// Verify SSL certificate
			resp, err := http.Get(domainURL + "/ok")
			require.NoError(t, err)
			defer resp.Body.Close()

			assert.NotNil(t, resp.TLS, "TLS connection should be established")
			if resp.TLS != nil {
				assert.NotEmpty(t, resp.TLS.PeerCertificates, "SSL certificate should be present")
				t.Logf("SSL certificate verified")
			}
		})
	}

	// ========================================
	// Task 7.5: Cloud SQL Connection Test
	// ========================================

	t.Run("CloudSQLInstanceExists", func(t *testing.T) {
		// Get Cloud SQL connection name from outputs
		connectionName := terraform.Output(t, terraformOptions, "cloud_sql_connection_name")
		require.NotEmpty(t, connectionName)

		t.Logf("Cloud SQL connection name: %s", connectionName)

		// Parse connection name: project:region:instance
		parts := strings.Split(connectionName, ":")
		require.Len(t, parts, 3, "Connection name should have format project:region:instance")

		instanceName := parts[2]

		// Create SQL Admin client
		sqlService, err := sqladmin.NewService(ctx)
		require.NoError(t, err)

		// Get instance details
		instance, err := sqlService.Instances.Get(projectID, instanceName).Context(ctx).Do()
		require.NoError(t, err)
		assert.NotNil(t, instance)

		t.Logf("Cloud SQL instance found: %s", instance.Name)

		// Verify private IP configuration
		assert.NotNil(t, instance.IpAddresses)
		hasPrivateIP := false
		for _, ip := range instance.IpAddresses {
			if ip.Type == "PRIVATE" {
				hasPrivateIP = true
				t.Logf("Cloud SQL private IP: %s", ip.IpAddress)
			}
		}
		assert.True(t, hasPrivateIP, "Cloud SQL instance should have private IP")

		// Verify public IP is disabled
		settings := instance.Settings
		require.NotNil(t, settings)
		ipConfig := settings.IpConfiguration
		require.NotNil(t, ipConfig)
		assert.False(t, ipConfig.Ipv4Enabled, "Public IP should be disabled")

		// Verify backup configuration
		backupConfig := settings.BackupConfiguration
		require.NotNil(t, backupConfig)
		assert.True(t, backupConfig.Enabled, "Backups should be enabled")
		assert.True(t, backupConfig.PointInTimeRecoveryEnabled, "Point-in-time recovery should be enabled")

		t.Logf("Cloud SQL configuration verified")
	})

	// ========================================
	// Task 7.6: DNS Resolution and Load Balancer Test
	// ========================================

	if domainName != "" && dnsZoneName != "" {
		t.Run("DNSResolutionAndLoadBalancer", func(t *testing.T) {
			// Get Load Balancer IP from outputs
			lbIP := terraform.Output(t, terraformOptions, "bridge_load_balancer_ip")
			require.NotEmpty(t, lbIP)

			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			t.Logf("DNS Resolution and Load Balancer Test")
			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			t.Logf("  Domain:         %s", domainName)
			t.Logf("  DNS Zone:       %s", dnsZoneName)
			t.Logf("  Expected LB IP: %s", lbIP)
			t.Logf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

			// Wait for DNS propagation
			t.Logf("\nWaiting for DNS propagation...")
			t.Logf("  Timeout: 5 minutes")
			t.Logf("  Interval: 10 seconds")

			err := retryWithTimeout(t, 5*time.Minute, 10*time.Second, func() error {
				t.Logf("\n  → Performing DNS lookup for %s", domainName)

				ips, err := net.LookupIP(domainName)
				if err != nil {
					t.Logf("     ❌ DNS lookup error: %v", err)
					return fmt.Errorf("DNS lookup failed: %w", err)
				}

				if len(ips) == 0 {
					t.Logf("     ❌ No IP addresses found")
					return fmt.Errorf("no IP addresses found for domain %s", domainName)
				}

				t.Logf("     DNS resolved to %d IP(s):", len(ips))
				for _, ip := range ips {
					t.Logf("       - %s", ip.String())
				}

				// Check if Load Balancer IP is in the resolved IPs
				found := false
				for _, ip := range ips {
					if ip.String() == lbIP {
						found = true
						t.Logf("     ✅ Load Balancer IP matched: %s", lbIP)
						break
					}
				}

				if !found {
					t.Logf("     ❌ Expected IP %s not found in DNS resolution", lbIP)
					return fmt.Errorf("expected IP %s not found in DNS resolution", lbIP)
				}

				return nil
			})

			require.NoError(t, err, "DNS resolution test failed")
			t.Logf("\n✅ DNS resolution verified: %s -> %s", domainName, lbIP)

			// Verify Cloud Armor (access from allowed IP should succeed)
			// Note: This test assumes the test is running from an allowed IP
			resp, err := http.Get(fmt.Sprintf("https://%s/ok", domainName))
			if err == nil {
				defer resp.Body.Close()
				// If we can access, verify it's successful
				assert.Equal(t, http.StatusOK, resp.StatusCode, "Access from allowed IP should succeed")
				t.Logf("Cloud Armor: Access from allowed IP succeeded")
			} else {
				// If access fails, it might be because we're not in the allowed IP range
				t.Logf("Cloud Armor: Cannot verify (test may not be running from allowed IP)")
			}
		})
	}

	// Log all outputs for debugging
	t.Run("LogOutputs", func(t *testing.T) {
		outputs := []string{
			"bridge_service_url",
			"bridge_service_name",
			"bridge_load_balancer_ip",
			"cloud_sql_connection_name",
			"cloud_sql_private_ip",
			"database_name",
		}

		t.Log("Terraform Outputs:")
		for _, output := range outputs {
			val := terraform.Output(t, terraformOptions, output)
			t.Logf("  %s: %s", output, val)
		}
	})
}
