# CI/CD Deployment Guide

> How to configure Stage 5 (Deploy) to deploy to an external Kubernetes cluster.

## Pipeline Overview

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐
│  Lint   │───▶│  Test   │───▶│  Build  │───▶│  Push   │───▶│  Deploy  │
│ (Ruff)  │    │(Pytest) │    │(Docker) │    │ (GHCR)  │    │  (Helm)  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └──────────┘
     │              │              │              │               │
     └──────────────┴──────────────┴──────────────┴───────────────┘
                           On: Pull Request
     
     └──────────────┴──────────────┴──────────────┴───────────────┘
                           On: Push to main/master
```

## Stage 5: Deploy to External Cluster

Stage 5 (Deploy) is the final stage that deploys the application to a Kubernetes cluster. It:

1. **Runs only on main/master** - Triggered after successful push to GHCR
2. **Uses GitHub Environments** - Optional approval gate for production
3. **Deploys with Helm** - Uses the same chart tested locally
4. **Verifies deployment** - Waits for rollout and confirms pods are running

---

## Configuration Requirements

### Required GitHub Secrets

Add these secrets in your repository: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | `wJalrXUtnFEMI...` |
| `EKS_CLUSTER_NAME` | Name of your EKS cluster | `production-cluster` |
| `AWS_REGION` | AWS region where cluster is deployed | `us-east-1` |

### IAM Permissions Required

The IAM user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

### EKS Cluster Access

The IAM user must be added to the EKS cluster's `aws-auth` ConfigMap:

```bash
# Get current aws-auth configmap
kubectl -n kube-system get configmap aws-auth -o yaml > aws-auth.yaml

# Add to mapUsers section:
# - userarn: arn:aws:iam::ACCOUNT_ID:user/github-actions-user
#   username: github-actions
#   groups:
#     - system:masters

# Apply changes
kubectl apply -f aws-auth.yaml
```

### Step-by-Step Setup

1. **Create IAM User** for GitHub Actions
   ```bash
   aws iam create-user --user-name github-actions-deploy
   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
   ```

2. **Create Access Keys**
   ```bash
   aws iam create-access-key --user-name github-actions-deploy
   # Save the AccessKeyId and SecretAccessKey
   ```

3. **Add User to EKS Cluster**
   ```bash
   eksctl create iamidentitymapping \
     --cluster YOUR_CLUSTER_NAME \
     --arn arn:aws:iam::ACCOUNT_ID:user/github-actions-deploy \
     --username github-actions \
     --group system:masters
   ```

4. **Add Secrets to GitHub**
   - Go to repository **Settings → Secrets and variables → Actions**
   - Add each secret listed above

---

## How the Deploy Stage Works

```yaml
deploy:
  name: Deploy to AWS EKS
  runs-on: ubuntu-latest
  needs: push                    # Only runs after push succeeds
  if: github.ref == 'refs/heads/main'  # Only on main branch
  environment: production        # Uses production environment (optional)
  
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Update kubeconfig for EKS
      run: |
        aws eks update-kubeconfig \
          --name ${{ secrets.EKS_CLUSTER_NAME }} \
          --region ${{ secrets.AWS_REGION }}

    - name: Install Helm
      uses: azure/setup-helm@v4
      with:
        version: 'v3.13.0'

    - name: Deploy with Helm
      run: |
        helm upgrade --install fastapi-app ./helm/fastapi-app \
          --set image.repository=ghcr.io/${{ github.repository }} \
          --set image.tag=${{ github.sha }} \
          --set image.pullPolicy=Always \
          --set config.APP_ENV=production \
          --wait \
          --timeout 300s

    - name: Verify deployment
      run: |
        kubectl rollout status deployment/fastapi-app
        kubectl get pods -l app.kubernetes.io/name=fastapi-app
```

### Key Features

| Feature | Implementation | Purpose |
|---------|----------------|---------|
| `--wait` | Helm waits for pods to be ready | Ensures deployment succeeds before marking job complete |
| `--timeout 300s` | 5 minute timeout | Fails fast if deployment takes too long |
| `image.tag=${{ github.sha }}` | Uses commit SHA | Exact version tracking |
| `image.pullPolicy=Always` | Force pull | Ensures latest image is used |
| `rollout status` | Watch deployment | Confirms all pods are running |

---

## Testing the Pipeline

### Local Simulation

Before pushing, you can simulate the deploy stage locally:

```bash
# Ensure you're connected to your cluster
kubectl config current-context

# Run the same helm command
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --set image.repository=ghcr.io/rupertbothma/devtest \
  --set image.tag=latest \
  --set config.APP_ENV=production \
  --wait

# Verify
kubectl get pods -l app.kubernetes.io/name=fastapi-app
```

### Trigger the Pipeline

```bash
# Merge feature branch to main
git checkout main
git merge feature/add-version-endpoint
git push origin main
```

Then watch the Actions tab:
1. **Lint** → 2. **Test** → 3. **Build** → 4. **Push** → 5. **Deploy** ✅

---

## Rollback

If deployment fails or you need to revert:

```bash
# View release history
helm history fastapi-app

# Rollback to previous version
helm rollback fastapi-app 1

# Or via kubectl (forces re-pull of previous image)
kubectl rollout undo deployment/fastapi-app
```

---

## Troubleshooting

### Deploy Stage Skipped

**Cause**: The deploy stage requires the KUBE_CONFIG secret.

**Solution**: Add the secret as described above. If the secret is missing, the stage will fail at the "Configure Kubernetes access" step.

### Authentication Failed

**Error**: `Unable to connect to the server: x509: certificate signed by unknown authority`

**Solution**: Ensure the kubeconfig includes the cluster CA certificate or use `insecure-skip-tls-verify: true` for testing.

### ImagePullBackOff

**Error**: Pod can't pull image from GHCR.

**Solution**: 
1. Ensure GHCR package is public, or
2. Create imagePullSecret in the cluster:

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT
```

Then add to values:
```yaml
imagePullSecrets:
  - name: ghcr-secret
```

---

## Security Best Practices

1. **Use short-lived credentials** - Prefer OIDC (OpenID Connect) over static secrets
2. **Least privilege** - Create a service account with only deployment permissions
3. **Rotate secrets** - Regularly rotate the KUBE_CONFIG secret
4. **Use environments** - Require approval for production deployments
5. **Audit logs** - Review deployment history regularly
