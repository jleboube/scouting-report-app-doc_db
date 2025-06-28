#!/bin/bash

# Scout Pro - Monitoring Script
# Monitors application health and sends alerts

set -e

# Configuration
BACKEND_URL="http://localhost:5000/api/health"
FRONTEND_URL="http://localhost:3000/health"
PROXY_MANAGER_URL="http://localhost:81"
ALERT_EMAIL=""  # Set email for alerts
SLACK_WEBHOOK=""  # Set Slack webhook for alerts
LOG_FILE="./logs/monitor.log"
ALERT_COOLDOWN=300  # 5 minutes between alerts for same issue

# Ensure logs directory exists
mkdir -p "./logs"

# Utility functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    local severity="$2"  # INFO, WARNING, ERROR, CRITICAL
    
    log_message "ALERT [$severity]: $message"
    
    # Send email alert if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Scout Pro Alert [$severity]" "$ALERT_EMAIL"
    fi
    
    # Send Slack alert if configured
    if [ -n "$SLACK_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 Scout Pro Alert [$severity]: $message\"}" \
            "$SLACK_WEBHOOK" &>/dev/null
    fi
}

check_http_endpoint() {
    local url="$1"
    local name="$2"
    local expected_status="${3:-200}"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        log_message "✅ $name is healthy (HTTP $response)"
        return 0
    else
        log_message "❌ $name is unhealthy (HTTP $response)"
        return 1
    fi
}

check_docker_container() {
    local container="$1"
    local name="$2"
    
    if docker ps --filter "name=$container" --filter "status=running" --format "table {{.Names}}" | grep -q "$container"; then
        log_message "✅ $name container is running"
        return 0
    else
        log_message "❌ $name container is not running"
        return 1
    fi
}

check_disk_space() {
    local threshold="${1:-85}"  # Alert if disk usage > 85%
    local usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -lt "$threshold" ]; then
        log_message "✅ Disk usage is healthy ($usage%)"
        return 0
    else
        log_message "⚠️  Disk usage is high ($usage%)"
        return 1
    fi
}

check_memory_usage() {
    local threshold="${1:-85}"  # Alert if memory usage > 85%
    local usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [ "$usage" -lt "$threshold" ]; then
        log_message "✅ Memory usage is healthy ($usage%)"
        return 0
    else
        log_message "⚠️  Memory usage is high ($usage%)"
        return 1
    fi
}

check_database_connection() {
    local container="scoutpro-mongo"
    
    if docker exec "$container" mongosh --quiet --eval "db.adminCommand('ping')" &>/dev/null; then
        log_message "✅ Database connection is healthy"
        return 0
    else
        log_message "❌ Database connection failed"
        return 1
    fi
}

check_ssl_certificate() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        log_message "ℹ️  No domain configured for SSL check"
        return 0
    fi
    
    local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates | grep "notAfter" | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ "$days_until_expiry" -gt 30 ]; then
        log_message "✅ SSL certificate is healthy ($days_until_expiry days remaining)"
        return 0
    elif [ "$days_until_expiry" -gt 7 ]; then
        log_message "⚠️  SSL certificate expires in $days_until_expiry days"
        return 1
    else
        log_message "🚨 SSL certificate expires in $days_until_expiry days"
        return 2
    fi
}

# Main monitoring function
run_health_checks() {
    log_message "Starting health checks..."
    
    local errors=0
    local warnings=0
    
    # Check Docker containers
    if ! check_docker_container "scoutpro-mongo" "MongoDB"; then
        send_alert "MongoDB container is not running" "CRITICAL"
        ((errors++))
    fi
    
    if ! check_docker_container "scoutpro-backend" "Backend"; then
        send_alert "Backend container is not running" "CRITICAL"
        ((errors++))
    fi
    
    if ! check_docker_container "scoutpro-frontend" "Frontend"; then
        send_alert "Frontend container is not running" "CRITICAL"
        ((errors++))
    fi
    
    if ! check_docker_container "scoutpro-proxy-manager" "Nginx Proxy Manager"; then
        send_alert "Nginx Proxy Manager container is not running" "ERROR"
        ((errors++))
    fi
    
    # Check HTTP endpoints
    if ! check_http_endpoint "$BACKEND_URL" "Backend API"; then
        send_alert "Backend API health check failed" "CRITICAL"
        ((errors++))
    fi
    
    if ! check_http_endpoint "$FRONTEND_URL" "Frontend"; then
        send_alert "Frontend health check failed" "ERROR"
        ((errors++))
    fi
    
    # Check database connection
    if ! check_database_connection; then
        send_alert "Database connection failed" "CRITICAL"
        ((errors++))
    fi
    
    # Check system resources
    if ! check_disk_space 85; then
        send_alert "Disk usage is above 85%" "WARNING"
        ((warnings++))
    fi
    
    if ! check_memory_usage 85; then
        send_alert "Memory usage is above 85%" "WARNING"
        ((warnings++))
    fi
    
    # Check SSL certificate if domain is configured
    if [ -n "$DOMAIN_NAME" ]; then
        ssl_result=$(check_ssl_certificate "$DOMAIN_NAME"; echo $?)
        if [ "$ssl_result" = "1" ]; then
            send_alert "SSL certificate expires soon for $DOMAIN_NAME" "WARNING"
            ((warnings++))
        elif [ "$ssl_result" = "2" ]; then
            send_alert "SSL certificate expires very soon for $DOMAIN_NAME" "ERROR"
            ((errors++))
        fi
    fi
    
    # Summary
    if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
        log_message "🎉 All health checks passed"
    else
        log_message "⚠️  Health check summary: $errors errors, $warnings warnings"
    fi
    
    return $((errors + warnings))
}

# Performance monitoring
check_performance() {
    log_message "Checking performance metrics..."
    
    # API response time
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" --max-time 10 "$BACKEND_URL" 2>/dev/null || echo "999")
    if (( $(echo "$response_time > 5.0" | bc -l) )); then
        send_alert "API response time is slow: ${response_time}s" "WARNING"
    else
        log_message "✅ API response time: ${response_time}s"
    fi
    
    # Database performance
    local db_response_time=$(docker exec scoutpro-mongo mongosh --quiet --eval "
        var start = new Date();
        db.users.findOne();
        var end = new Date();
        print((end - start) / 1000);
    " 2>/dev/null || echo "999")
    
    if (( $(echo "$db_response_time > 2.0" | bc -l) )); then
        send_alert "Database response time is slow: ${db_response_time}s" "WARNING"
    else
        log_message "✅ Database response time: ${db_response_time}s"
    fi
}

# Log analysis
analyze_logs() {
    log_message "Analyzing application logs..."
    
    # Check for errors in backend logs
    local error_count=$(docker logs scoutpro-backend --since="1h" 2>&1 | grep -i "error" | wc -l)
    if [ "$error_count" -gt 10 ]; then
        send_alert "High error rate in backend logs: $error_count errors in last hour" "WARNING"
    fi
    
    # Check for failed authentication attempts
    local auth_failures=$(docker logs scoutpro-backend --since="1h" 2>&1 | grep -i "invalid credentials" | wc -l)
    if [ "$auth_failures" -gt 20 ]; then
        send_alert "High authentication failure rate: $auth_failures failed attempts in last hour" "WARNING"
    fi
}

# Cleanup old logs
cleanup_logs() {
    log_message "Cleaning up old logs..."
    
    # Keep last 7 days of monitor logs
    find ./logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Rotate Docker logs if they're too large
    docker system prune -f --filter "until=168h" &>/dev/null || true
}

# Main execution
main() {
    echo "🔍 Scout Pro Monitoring - $(date)"
    echo "=================================="
    
    # Load environment variables if .env exists
    if [ -f .env ]; then
        source .env
    fi
    
    case "${1:-health}" in
        "health"|"h")
            run_health_checks
            ;;
        "performance"|"perf"|"p")
            check_performance
            ;;
        "logs"|"l")
            analyze_logs
            ;;
        "cleanup"|"c")
            cleanup_logs
            ;;
        "full"|"f")
            run_health_checks
            check_performance
            analyze_logs
            cleanup_logs
            ;;
        "watch"|"w")
            echo "Starting continuous monitoring (Ctrl+C to stop)..."
            while true; do
                run_health_checks
                sleep 300  # Check every 5 minutes
            done
            ;;
        *)
            echo "Usage: $0 {health|performance|logs|cleanup|full|watch}"
            echo ""
            echo "Commands:"
            echo "  health      - Run health checks"
            echo "  performance - Check performance metrics"
            echo "  logs        - Analyze application logs"
            echo "  cleanup     - Clean up old logs"
            echo "  full        - Run all checks"
            echo "  watch       - Continuous monitoring"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"