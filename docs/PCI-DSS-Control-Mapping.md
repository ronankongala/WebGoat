# PCI-DSS 4.0 Control Mapping
## Application Security Pipeline + Secrets Management Lab
**Author:** Ronan Kongala  
**Date:** August 2026  
**Scope:** WebGoat deliberately vulnerable application deployed via Terraform-managed Docker container, secured by a 3-stage CI/CD security gate pipeline (Semgrep SAST, Checkov IaC, Trivy container scanning), DAST scanning via OWASP ZAP, secrets management via HashiCorp Vault, and SSO/MFA via Okta OIDC.

---

## SAQ Scope Declaration

This lab environment scopes as a **SAQ A-EP equivalent** — a web application that handles application credentials and authenticates users via a third-party identity provider (Okta). No actual cardholder data (CHD) is processed; the mapping below demonstrates control coverage that would apply to a production system handling CHD in this architecture.

---

## Control Mapping Table

| PCI-DSS 4.0 Requirement | Requirement Description | Lab Control | Implementation Evidence |
|---|---|---|---|
| **Req 2.2.1** | System components are configured and managed using configuration standards | Terraform `main.tf` defines container configuration as code; `restart = "on-failure"` and port bindings enforced declaratively | `terraform/main.tf`; `terraform apply` output |
| **Req 2.2.7** | All non-console administrative access is encrypted | Okta OIDC enforces encrypted token-based authentication; no plaintext credential exchange over the wire | `23-okta-app-config.png`; OIDC Authorization Code flow with Client Secret |
| **Req 3.5.1** | Primary account number (PAN) is secured | Application credentials (DB username, password, JDBC URL, JWT secret) stored in HashiCorp Vault KV secrets engine — not hardcoded in source or config files | `20-vault-secrets-stored.png`; `vault kv get secret/webgoat/database` |
| **Req 3.7.1** | Key/secret management procedures are defined and implemented | Vault secret versioning demonstrated: `secret/webgoat/database` rotated from `version 1` to `version 2`; old version retained for rollback | `21-vault-rotation.png`; Vault metadata showing `version: 2` |
| **Req 6.2.4** | Software development practices prevent common vulnerabilities | Semgrep SAST scan with `p/owasp-top-ten` and `p/security-audit` rulesets runs on every push; 66 findings surfaced in WebGoat source across Java, JS, YAML, and Terraform | `14-semgrep-findings.png`; `semgrep-results.json` artifact |
| **Req 6.3.2** | An inventory of bespoke and custom software is maintained | GitHub repository at `github.com/ronankongala/WebGoat` tracks all custom configurations (Terraform, Dockerfile, workflow YAML) with commit history and change attribution | `13-github-repo-terraform.png` |
| **Req 6.3.3** | All system components are protected from known vulnerabilities | Trivy scans the `webgoat/webgoat:latest` container image on every pipeline run; identified 11 HIGH CVEs in Ubuntu 24.04 base layer and 60 vulnerabilities in `webgoat.jar` | `17-trivy-scan.png`; Trivy report summary |
| **Req 6.4.1** | Public-facing web applications are protected against attacks | OWASP ZAP active scan against `http://localhost:8080/WebGoat` surfaced 8 alerts including Missing Anti-CSRF Tokens (5 instances), CSP Header Not Set, Missing Anti-Clickjacking Header, and Cookie without SameSite attribute | `18-zap-alerts.png`; `docs/zap-report.html` |
| **Req 6.4.2** | An automated technical solution is deployed to detect and prevent web-based attacks | GitHub Actions pipeline gates deployment on Semgrep (SAST), Checkov (IaC), and Trivy (container) scan results; pipeline fails on critical findings before any deployment occurs | `16-pipeline-all-green.png`; `.github/workflows/semgrep.yml` |
| **Req 7.2.1** | Access control systems are configured to enforce least privilege | Okta OIDC integration enforces authentication before application access; Authorization Code flow with PKCE-capable client (`0oa16726t63VWCvXz698`) scoped to WebGoat-Lab only | `23-okta-app-config.png` |
| **Req 8.4.2** | Multi-factor authentication (MFA) is implemented for all access into the CDE | Okta Verify MFA enforced on the Okta org (`northeastern-integrator-3024697`); all users authenticating via Okta SSO must complete MFA challenge | `22-okta-dashboard.png`; Okta Verify enrollment during setup |
| **Req 8.6.1** | System/application accounts are managed rigorously | Application credentials managed exclusively through Vault KV engine; no credentials appear in source code, environment variables, or Terraform state | `20-vault-secrets-stored.png`; `.gitignore` excluding `*.tfstate` |
| **Req 10.2.1** | Audit logs are protected from destruction and unauthorized modifications | GitHub Actions workflow logs retained by GitHub for 90 days; all pipeline runs (including failures) logged with commit SHA, actor, and timestamp | GitHub Actions run history at `github.com/ronankongala/WebGoat/actions` |
| **Req 11.3.1** | Internal vulnerability scans are performed | Semgrep (SAST) and Trivy (container CVE) scans constitute internal vulnerability scanning; both run automatically on push to `main` | `14-semgrep-findings.png`; `17-trivy-scan.png` |
| **Req 11.3.2** | External vulnerability scans are performed | OWASP ZAP active scan simulates external attacker perspective against the running WebGoat application; 961 requests sent, 8 vulnerability categories identified | `18-zap-alerts.png`; `docs/zap-report.html` |
| **Req 12.3.2** | A targeted risk analysis is performed | Checkov IaC scan maps Dockerfile misconfigurations to Prisma Cloud policy IDs (`CKV_DOCKER_7`, `CKV_DOCKER_8`, `CKV_DOCKER_2`) with documented remediation guidance and accepted risk justification | `15-checkov-scan.png` |

---

## Accepted Risk Register

The following findings were identified and accepted for this lab environment. In a production cardholder data environment, each would require remediation or compensating controls.

| Finding | Tool | PCI-DSS Req | Risk Disposition | Justification |
|---|---|---|---|---|
| `webgoat/webgoat:latest` tag (no pinned version) | Checkov CKV_DOCKER_7 | 6.3.3 | Accepted — lab only | Lab uses latest for convenience; production would pin to a specific digest |
| Container runs as root (USER root) | Checkov CKV_DOCKER_8 | 2.2.1 | Accepted — lab only | Intentional for lab; production would use a non-root service account |
| No HEALTHCHECK instruction | Checkov CKV_DOCKER_2 | 2.2.1 | Accepted — lab only | WebGoat has a built-in health endpoint; Dockerfile HEALTHCHECK not configured |
| 11 HIGH CVEs in Ubuntu 24.04 base layer | Trivy | 6.3.3 | Accepted — no fix available | OS-level CVEs with no available patched base image at scan time; monitoring in place via pipeline |
| Missing Anti-CSRF Tokens (5 instances) | OWASP ZAP | 6.4.1 | Accepted — intentional | WebGoat is a deliberately vulnerable app; CSRF is a training scenario, not a production gap |
| CSP Header Not Set | OWASP ZAP | 6.4.1 | Accepted — intentional | WebGoat intentionally omits security headers for training purposes |

---

## Architecture Summary

```
Developer Push
      ↓
GitHub Actions CI/CD
      ↓
┌─────────────────────────────────┐
│  Security Gate (semgrep.yml)    │
│  1. Semgrep SAST — 66 findings  │
│  2. Checkov IaC — 3 failures    │
│  3. Trivy container — 71 CVEs   │
└─────────────────────────────────┘
      ↓
WebGoat container (Terraform-managed)
      ↓
OWASP ZAP DAST — 8 alerts
      ↓
HashiCorp Vault — secrets at rest
      ↓
Okta OIDC — SSO + MFA
```

---

## References

- PCI Security Standards Council. *PCI DSS v4.0.* March 2022.
- WebGoat source: `github.com/ronankongala/WebGoat`
- Semgrep results: `semgrep-results.json` (GitHub Actions artifact, run #5+)
- ZAP report: `docs/zap-report.html`
- Checkov policy reference: `docs.prismacloud.io/en/enterprise-edition/policy-reference/docker-policies`
- Trivy CVE database: `mirror.gcr.io/aquasec/trivy-db:2`
