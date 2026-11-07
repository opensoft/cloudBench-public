#!/bin/bash
# Layer 2 Cloud Admin Tools Installation Script (Minimal)
# Core action-oriented cloud tools only

set -e

echo "=========================================="
echo "Installing Layer 2 Cloud Admin Tools"
echo "=========================================="

# ========================================
# INFRASTRUCTURE AS CODE
# ========================================

echo "Installing Terragrunt..."
TERRAGRUNT_VERSION=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$TERRAGRUNT_VERSION" ]; then
    TERRAGRUNT_VERSION="1.1.0"
fi
curl -L "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" -o /usr/local/bin/terragrunt
chmod +x /usr/local/bin/terragrunt
terragrunt --version

echo "Installing Pulumi..."
curl -fsSL https://get.pulumi.com | sh
mv /root/.pulumi/bin/* /usr/local/bin/
pulumi version

echo "Installing OpenSpec CLI..."
OPENSPEC_VERSION="1.6.0"
npm install --global --omit=dev "@fission-ai/openspec@${OPENSPEC_VERSION}"
openspec --version

# ========================================
# COST & FINOPS
# ========================================

echo "Installing Infracost..."
INFRACOST_VERSION=$(curl -s https://api.github.com/repos/infracost/cli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$INFRACOST_VERSION" ]; then
    INFRACOST_VERSION="2.7.0"
fi
curl -L "https://github.com/infracost/cli/releases/download/v${INFRACOST_VERSION}/infracost-linux-amd64.tar.gz" -o /tmp/infracost.tar.gz
tar -xzf /tmp/infracost.tar.gz -C /usr/local/bin infracost
rm /tmp/infracost.tar.gz
chmod +x /usr/local/bin/infracost
infracost --version

# ========================================
# SECURITY & COMPLIANCE
# ========================================

# Prowler and Checkov skipped - large Python dependencies
# Install manually if needed: pip install prowler checkov

echo "Installing Trivy..."
TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$TRIVY_VERSION" ]; then
    TRIVY_VERSION="0.72.0"
fi
curl -L "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -o /tmp/trivy.tar.gz
tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy
rm /tmp/trivy.tar.gz
chmod +x /usr/local/bin/trivy
trivy --version

echo "Installing Vault CLI..."
VAULT_VERSION=$(curl -s https://api.github.com/repos/hashicorp/vault/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$VAULT_VERSION" ]; then
    VAULT_VERSION="2.0.3"
fi
curl -L "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o /tmp/vault.zip
unzip -o /tmp/vault.zip -d /usr/local/bin
rm /tmp/vault.zip
chmod +x /usr/local/bin/vault
vault --version

echo "Installing SOPS..."
SOPS_VERSION="3.13.2"
SOPS_SHA256="154dfe4cd70554bdd82b98e4cd4acf191d43d01ead6f00a73477aa44c4ac42ef"
curl -fsSL \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    -o /tmp/sops
echo "${SOPS_SHA256}  /tmp/sops" | sha256sum --check --strict
install -m 0755 /tmp/sops /usr/local/bin/sops
rm -f /tmp/sops
sops --version

echo "Installing age..."
AGE_VERSION="1.3.1"
AGE_SHA256="bdc69c09cbdd6cf8b1f333d372a1f58247b3a33146406333e30c0f26e8f51377"
curl -fsSL \
    "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/age.tar.gz
echo "${AGE_SHA256}  /tmp/age.tar.gz" | sha256sum --check --strict
tar -xzf /tmp/age.tar.gz -C /tmp
install -m 0755 /tmp/age/age /usr/local/bin/age
install -m 0755 /tmp/age/age-keygen /usr/local/bin/age-keygen
rm -rf /tmp/age /tmp/age.tar.gz
age --version

# ========================================
# CLUSTER MANAGEMENT
# ========================================

echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "Installing Flux CLI..."
FLUX_VERSION="2.9.2"
FLUX_SHA256="4092b367fd060097976fb7261601f79420ecf7266328417dfd8dfee27de0e6a3"
curl -fsSL \
    "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz" \
    -o /tmp/flux.tar.gz
echo "${FLUX_SHA256}  /tmp/flux.tar.gz" | sha256sum --check --strict
tar -xzf /tmp/flux.tar.gz -C /tmp flux
install -m 0755 /tmp/flux /usr/local/bin/flux
rm -f /tmp/flux /tmp/flux.tar.gz
flux version --client

echo "Installing Azure kubelogin..."
KUBELOGIN_VERSION="0.2.19"
KUBELOGIN_SHA256="ebaeff02aa899c5cae6a2b954b64fc02738185319df2570f7dc053451efa4b2f"
curl -fsSL \
    "https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip" \
    -o /tmp/kubelogin.zip
echo "${KUBELOGIN_SHA256}  /tmp/kubelogin.zip" | sha256sum --check --strict
unzip -q /tmp/kubelogin.zip -d /tmp/kubelogin
install -m 0755 /tmp/kubelogin/bin/linux_amd64/kubelogin /usr/local/bin/kubelogin
rm -rf /tmp/kubelogin /tmp/kubelogin.zip
kubelogin --version

echo "Installing Velero..."
VELERO_VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$VELERO_VERSION" ]; then
    VELERO_VERSION="1.18.2"
fi
curl -L "https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-amd64.tar.gz" -o /tmp/velero.tar.gz
tar -xzf /tmp/velero.tar.gz -C /tmp
mv /tmp/velero-v${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/
rm -rf /tmp/velero*
chmod +x /usr/local/bin/velero
velero version --client-only

# ========================================
# OBSERVABILITY MANAGEMENT
# ========================================

echo "Installing Teleport..."
TELEPORT_VERSION=$(curl -s https://api.github.com/repos/gravitational/teleport/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)
if [ -z "$TELEPORT_VERSION" ]; then
    TELEPORT_VERSION="18.9.2"
fi
curl -L "https://cdn.teleport.dev/teleport-v${TELEPORT_VERSION}-linux-amd64-bin.tar.gz" -o /tmp/teleport.tar.gz
tar -xzf /tmp/teleport.tar.gz -C /tmp
mv /tmp/teleport/tsh /usr/local/bin/
mv /tmp/teleport/tctl /usr/local/bin/
rm -rf /tmp/teleport*
chmod +x /usr/local/bin/tsh /usr/local/bin/tctl
tsh version

echo ""
echo "=========================================="
echo "✓ Layer 2 Cloud Tools Installation Complete"
echo "=========================================="
echo ""
echo "Core Tools Installed:"
echo "  - Terragrunt, Pulumi, OpenSpec (IaC & governance)"
echo "  - Infracost (Cost)"
echo "  - Trivy, Vault, SOPS, age (Security & secrets)"
echo "  - Helm, Flux, Azure kubelogin, Velero (Cluster)"
echo "  - Teleport (Access)"
echo ""
echo "Skipped (install manually if needed):"
echo "  - Prowler, Checkov (large Python deps)"
echo "  - CloudQuery, SkyPilot, Steampipe, Komiser, Grafana CLI"
