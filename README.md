# Kong on ECS with Terraform and GitHub Actions

This repository sets up [Kong Gateway](https://konghq.com/kong-enterprise/) on AWS Elastic Container Service (ECS) using Terraform for infrastructure provisioning and GitHub Actions for CI/CD. It also includes a custom Kong plugin to inject and manage an `X-Correlation-ID` header for enhanced traceability across your APIs.

---

## Features

- **Kong Gateway**: Deployed on AWS ECS for scalable API gateway functionality.
- **Custom Plugin**: Implements `X-Correlation-ID` header injection to track requests across services. If a correlation ID is already present in the request, it is preserved for continuity.
- **Terraform**: Infrastructure-as-Code (IaC) to provision ECS clusters, services, and other required resources.
- **GitHub Actions**: Automates the deployment pipeline for Kong and the custom plugin.

---

## Getting Started

### Prerequisites

1. **Terraform** installed. Refer to [Terraform installation guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
2. **AWS CLI** configured with appropriate access permissions.
3. **Docker** installed and running.
4. A **GitHub Actions runner** (hosted or self-hosted) for CI/CD workflows.

---

### Installation

1. Clone this repository:
    You can also make a fork in your own GitHub account from this repo
    
    ```bash
    git clone https://github.com/glennbech/kong-ecs.git
    cd kong-ecs
    ```

2. Initialize Terraform:
    ```bash
    terraform init
    ```

3. Plan and apply the infrastructure:
    You can also rely on Github actions to do this for you in your repo.
    ```bash
    terraform plan
    terraform apply
    ```

4. Set up your environment variables for GitHub Actions. Add the following secrets in your GitHub repository:
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
    - `DOCKER_USERNAME`
    - `DOCKER_PASSWORD`

---

### Custom Plugin: `X-Correlation-ID`

The custom plugin automatically manages the `X-Correlation-ID` header in requests. If a request doesn't have a correlation ID, the plugin generates one and attaches it to the headers. If the request already contains an `X-Correlation-ID` header, the plugin preserves it for traceability.

**How to test the plugin using `curl`:**

1. Ensure Kong is up and running, and the plugin is enabled on a specific route or service.
2. Use `curl` to send a request without an `X-Correlation-ID`:
    ```bash
    curl -i http://<KONG_HOST>:<KONG_PORT>/<YOUR_ROUTE>
    ```
3. Check the response headers for `X-Correlation-ID`:
    ```plaintext
    HTTP/1.1 200 OK
    Content-Type: application/json
    X-Correlation-ID: f81d4fae-7dec-11d0-a765-00a0c91e6bf6
    ```

4. Send another request, this time including an `X-Correlation-ID`:
    ```bash
    curl -i -H "X-Correlation-ID: custom-id-12345" http://<KONG_HOST>:<KONG_PORT>/<YOUR_ROUTE>
    ```

5. Verify that the `X-Correlation-ID` in the response matches the one you sent:
    ```plaintext
    HTTP/1.1 200 OK
    Content-Type: application/json
    X-Correlation-ID: custom-id-12345
    ```

Replace `<KONG_HOST>` and `<KONG_PORT>` with the actual host and port of your Kong Gateway, and `<YOUR_ROUTE>` with the route you're testing.

---

### GitHub Actions Workflow

This repository includes a CI/CD pipeline defined in `.github/workflows/deploy.yml`. The workflow:
- Builds and pushes the Kong container image to Amazon Elastic Container Registry (ECR).
- Deploys the updated ECS service with the new image.

**Manual Trigger**: Trigger the workflow via the GitHub Actions UI or automatically on changes to the main branch.

---

Let me know if you have further refinements in mind!