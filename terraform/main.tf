yesterraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # S3 backend — يحفظ الـ state على AWS
  backend "s3" {
    bucket = "abdo-portfolio-tfstate"
    key    = "portfolio/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC ─────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "portfolio-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true   # توفير في التكلفة

  # Tags مطلوبة للـ EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ── ECR ─────────────────────────────────────────
# هنا بيتحفظ الـ Docker image
resource "aws_ecr_repository" "portfolio" {
  name                 = "portfolio"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true   # بيسكان الـ image للـ vulnerabilities
  }
}

# ── EKS Cluster ─────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "portfolio-cluster"
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public endpoint عشان تقدر تـaccess الـ cluster
  cluster_endpoint_public_access = true

  # Node group — أرخص option للـ portfolio
  eks_managed_node_groups = {
    main = {
      instance_types = ["t3.small"]   # رخيص وكافي
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
}

# ── AWS Load Balancer Controller IAM ────────────
# الـ Ingress محتاج الـ permission دي عشان يعمل ALB
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "portfolio-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}