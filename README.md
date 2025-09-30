# Example Logic App with Terraform

An example Azure Logic App (Consumption) deployment using Terraform with parameterised workflow configuration.

## Overview
This project deploys an Azure Logic App that:
- Responds to HTTP GET requests.
- Returns a response based on parameters configured during Terraform deployment


## Prerequisites
- Terraform
- Azure CLI

### 1. Deployment Steps
```bash
# Clone the repository
git clone https://github.com/hasitha-u/example-logic-app-terraform.git
cd example-logic-app-terraform
```

### 2. Configure Variables
#### Create `terraform.tfvars`:
```hcl
location     = "East US"
environment  = "dev"
user_name    = "YourName"
```

### 3. Deploy
```bash
# Login to Azure
az login

# Deploy
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform plan
terraform apply
```

### Test
```bash
curl -X POST "$(terraform output -raw trigger_url)" 
```

### Cleanup
```bash
terraform destroy
```

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
