# DevOps End-to-End Project - Final Report

**Student Name:** [Your Name]  
**Date:** January 14, 2026  
**Project:** Simple DevOps API

---

## 1. Project Overview

This project demonstrates a complete DevOps workflow with a REST API backend (FastAPI) that includes CI/CD automation, observability, security scanning, containerization, and Kubernetes deployment.

**Key Statistics:**

- Backend Code: ~150 lines (core functionality)
- Docker Image: Multi-stage build with security hardening
- Kubernetes: 2 replicas with health probes
- CI/CD: 5-stage GitHub Actions pipeline

---

## 2. Architecture & Technology Stack

### Backend Service

- **Framework:** FastAPI 0.104.1 (Python 3.11)
- **Features:**
  - CRUD operations for items
  - Health check endpoint
  - Prometheus metrics endpoint
  - Structured JSON logging
  - Request tracing with UUIDs

### Infrastructure

- **Containerization:** Docker with multi-stage builds
- **Orchestration:** Kubernetes (Minikube locally)
- **Monitoring:** Prometheus + Grafana
- **Version Control:** Git/GitHub with feature branches

---

## 3. CI/CD Pipeline

**GitHub Actions Workflow** (`.github/workflows/ci-cd.yml`):

1. **Lint & Test Job**

   - Python dependency installation
   - API endpoint testing
   - Quick security check

2. **Security Scan Job**

   - SAST with Bandit (static code analysis)
   - Dependency vulnerability scan with Safety
   - Secrets detection
   - **DAST with ZAP** (dynamic security testing)
   - Fails on CRITICAL vulnerabilities

3. **Docker Build Job**

   - Multi-stage Docker image build
   - Container security scan with Trivy
   - Integration tests

4. **Deploy Simulation Job**

   - Deployment report generation
   - Only runs on `main` branch

5. **Windows Parity Job**
   - Cross-platform testing
   - Local script validation

---

## 4. Observability Implementation

### Metrics (Prometheus)

```
/metrics endpoint exposes:
- http_requests_total: Total HTTP requests by method/endpoint/status
- http_request_duration_seconds: Request latency histogram
- http_errors_total: Total errors by type
- items_total: Current item count gauge
```

### Logs (Structured JSON)

```json
{
  "time": "2026-01-14T15:52:47Z",
  "level": "INFO",
  "message": {
    "request_id": "412ae310-4f75-42cc-88bd-c6f98b5aa727",
    "event": "request_complete",
    "method": "GET",
    "path": "/health",
    "status": 200,
    "duration_ms": 0.98
  }
}
```

### Tracing

- UUID request IDs for request correlation
- Middleware tracking for all HTTP requests
- Duration measurements for performance analysis

**Dashboard:** Grafana accessible at `http://localhost:3001` (docker-compose)

---

## 5. Security Implementation

### SAST (Static Analysis)

- **Tool:** Bandit 1.7.5
- **Configuration:** `.bandit.yml` excludes test files
- **Result:** Clean scan with 0 high-severity issues

### Dependency Scanning

- **Tool:** Safety 2.3.5
- **Result:** 5 vulnerabilities found (none CRITICAL)
- **Action:** Pipeline fails on CRITICAL severity

### Container Scanning

- **Tool:** Trivy (Aqua Security)
- **Scope:** OS and library vulnerabilities
- **Result:** Scans Docker image before deployment

### DAST (Dynamic Analysis)

- **Tool:** OWASP ZAP Baseline Scan
- **Target:** Running API endpoints
- **Coverage:** Health, metrics, CRUD operations
- **Integration:** Automated in CI/CD pipeline

### Additional Security Measures

- Multi-stage Docker builds (minimal attack surface)
- Non-root container user (UID 1000)
- Security context in Kubernetes (runAsNonRoot)
- Read-only root filesystem consideration
- Resource limits to prevent DoS

---

## 6. Kubernetes Deployment

### Local Deployment (Minikube)

```bash
# Start Minikube
minikube start --driver=docker --cpus=2 --memory=4096

# Build image in Minikube
minikube docker-env | Invoke-Expression
docker build -t devops-api:latest .

# Deploy
kubectl apply -f k8s/
```

### Kubernetes Resources

- **Namespace:** `devops-api` (isolation)
- **ConfigMap:** Environment configuration
- **Deployment:** 2 replicas with rolling updates
- **Services:**
  - ClusterIP for internal communication
  - LoadBalancer for external access

### High Availability Features

- **Replicas:** 2 pods for redundancy
- **Probes:**
  - Liveness: Restarts unhealthy pods
  - Readiness: Prevents traffic to non-ready pods
- **Resource Management:**
  - Requests: 100m CPU, 128Mi memory
  - Limits: 500m CPU, 256Mi memory

### Deployment Verification

```bash
kubectl get all -n devops-api
kubectl logs -n devops-api -l app=devops-api
```

---

## 7. Docker Image Publishing

**Docker Hub Repository:** `[your-username]/devops-api:latest`

```bash
# Login to Docker Hub
docker login

# Tag image
docker tag devops-api:latest [your-username]/devops-api:latest

# Push image
docker push [your-username]/devops-api:latest
```

**Multi-stage Build Benefits:**

- Builder stage: Dependencies compilation
- Runtime stage: Minimal image (~150MB vs 1GB+)
- Security: Only production files included

---

## 8. Testing & Validation

### Local Testing

```bash
# Quick test script
.\scripts\quick-test.ps1

# Security scan
.\scripts\security-scan.ps1

# Docker Compose
docker-compose up
```

### Automated Tests (CI)

- Health endpoint returns 200 OK
- Metrics endpoint exposes Prometheus format
- CRUD operations functional
- Response time < 100ms

### Kubernetes Testing

```bash
# Port-forward to access locally
kubectl port-forward -n devops-api service/devops-api-service 8080:80

# Test endpoint
curl http://localhost:8080/health
```

---

## 9. Lessons Learned

### Technical Challenges

1. **TrustedHostMiddleware Issue:** Blocked Kubernetes health probes

   - **Solution:** Disabled in K8s, use NetworkPolicy instead

2. **Minikube Docker Daemon:** Connection issues on Windows

   - **Solution:** Use `minikube docker-env` properly

3. **Port Conflicts:** Local port 8000 already in use
   - **Solution:** Changed docker-compose to port 8001

### Best Practices Applied

- ✅ Fail fast: Security scans gate deployment
- ✅ Immutable infrastructure: Container-based
- ✅ Infrastructure as Code: K8s manifests in Git
- ✅ Observability first: Metrics/logs from day 1
- ✅ Security by default: Multiple scan layers

### What I Would Improve

- Add integration tests with pytest
- Implement Helm charts for easier K8s management
- Add distributed tracing with Jaeger
- Set up centralized logging with ELK stack
- Implement blue-green deployment strategy
- Add API rate limiting

---

## 10. Project Deliverables Checklist

- ✅ GitHub repository with complete source code
- ✅ Dockerfile with multi-stage build
- ✅ Kubernetes manifests (namespace, deployment, services)
- ✅ CI/CD pipeline (GitHub Actions - 5 jobs)
- ✅ Docker image (local + Docker Hub)
- ✅ Kubernetes deployment (Minikube)
- ✅ Metrics endpoint (/metrics - Prometheus format)
- ✅ Structured logging (JSON format)
- ✅ Request tracing (UUID-based)
- ✅ SAST scan (Bandit)
- ✅ DAST scan (OWASP ZAP)
- ✅ Container scan (Trivy)
- ✅ README.md with setup instructions
- ✅ Final report (this document)

---

## 11. Conclusion

This project successfully demonstrates end-to-end DevOps practices including:

- Modern development workflows (Git, PRs, reviews)
- Automated CI/CD with security gating
- Comprehensive observability
- Container security best practices
- Production-ready Kubernetes deployment

The implementation showcases how DevOps principles improve software quality, deployment speed, and operational reliability through automation and continuous feedback loops.

**Total Time Investment:** ~16 hours  
**Lines of Code:** ~150 (backend) + ~200 (infrastructure)  
**Deployment Success Rate:** 100% after fixes

---

## Appendix: Quick Reference

### Repository Structure

```
simple-devops-api/
├── app/
│   ├── main.py          # FastAPI application
│   └── models.py        # Data models
├── k8s/
│   ├── namespace.yaml   # K8s namespace
│   ├── configmap.yaml   # Configuration
│   ├── deployment.yaml  # Pod deployment
│   └── service.yaml     # Services
├── scripts/
│   ├── quick-test.ps1   # Local testing
│   ├── security-scan.ps1 # Security checks
│   └── deploy-minikube.ps1 # K8s deployment
├── .github/workflows/
│   └── ci-cd.yml        # GitHub Actions pipeline
├── Dockerfile           # Container definition
├── docker-compose.yml   # Local stack
├── requirements.txt     # Python dependencies
└── README.md            # Documentation
```

### Key Commands

```bash
# Local development
docker-compose up

# Run tests
.\scripts\quick-test.ps1

# Security scanning
.\scripts\security-scan.ps1

# Deploy to Kubernetes
.\scripts\deploy-minikube.ps1

# Access API
kubectl port-forward -n devops-api service/devops-api-service 8080:80
```
