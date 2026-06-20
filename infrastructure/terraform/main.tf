# main.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SmartRenewableEnergyPlatform"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/networking"
  
  environment       = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = {
    Name = "${var.environment}-vpc"
  }
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  environment       = var.environment
  cluster_name      = "${var.environment}-eks-cluster"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  node_desired_size = var.node_desired_size
  node_max_size     = var.node_max_size
  node_min_size     = var.node_min_size
  
  tags = {
    Name = "${var.environment}-eks"
  }
}

# Database Module
module "aurora" {
  source = "./modules/databases/aurora"
  
  environment       = var.environment
  cluster_name      = "${var.environment}-aurora"
  database_name     = "renewable_energy"
  master_username   = var.db_master_username
  master_password   = var.db_master_password
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.database_subnet_ids
  instance_class    = var.db_instance_class
  instance_count    = var.db_instance_count
  
  tags = {
    Name = "${var.environment}-aurora"
  }
}

module "dynamodb" {
  source = "./modules/databases/dynamodb"
  
  environment = var.environment
  
  tables = [
    {
      name         = "Telemetry"
      hash_key     = "PartitionKey"
      range_key    = "SortKey"
      billing_mode = "PAY_PER_REQUEST"
      ttl          = true
      ttl_attribute = "TTL"
      tags = {
        Name = "${var.environment}-telemetry"
      }
    },
    {
      name         = "Anomalies"
      hash_key     = "anomaly_id"
      billing_mode = "PAY_PER_REQUEST"
      tags = {
        Name = "${var.environment}-anomalies"
      }
    },
    {
      name         = "Alerts"
      hash_key     = "alert_id"
      billing_mode = "PAY_PER_REQUEST"
      tags = {
        Name = "${var.environment}-alerts"
      }
    }
  ]
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"
  
  environment = var.environment
  
  repositories = [
    "asset-service",
    "telemetry-service",
    "anomaly-detection-service",
    "maintenance-service",
    "alert-service"
  ]
}

# SQS Queues
module "sqs" {
  source = "./modules/sqs"
  
  environment = var.environment
  
  queues = [
    {
      name = "telemetry-queue"
      dead_letter_queue = {
        name = "telemetry-dlq"
        max_receive_count = 3
      }
      tags = {
        Name = "${var.environment}-telemetry-queue"
      }
    },
    {
      name = "anomaly-queue"
      dead_letter_queue = {
        name = "anomaly-dlq"
        max_receive_count = 3
      }
      tags = {
        Name = "${var.environment}-anomaly-queue"
      }
    }
  ]
}

# SNS Topics
module "sns" {
  source = "./modules/sns"
  
  environment = var.environment
  
  topics = [
    {
      name = "anomaly-topic"
      subscriptions = {
        sqs = {
          protocol = "sqs"
          endpoint = module.sqs.queue_arns["anomaly-queue"]
        }
        email = {
          protocol = "email"
          endpoint = "alerts@renewable-energy-platform.com"
        }
      }
      tags = {
        Name = "${var.environment}-anomaly-topic"
      }
    }
  ]
}

# Secrets Manager
module "secrets_manager" {
  source = "./modules/secrets_manager"
  
  environment = var.environment
  
  secrets = [
    {
      name = "asset-service/db-credentials"
      secret_string = jsonencode({
        host     = module.aurora.cluster_endpoint
        username = var.db_master_username
        password = var.db_master_password
        database = "renewable_energy"
      })
    },
    {
      name = "alert-service/secrets"
      secret_string = jsonencode({
        email_password = var.email_password
        slack_webhook  = var.slack_webhook
        pagerduty_key  = var.pagerduty_key
      })
    }
  ]
}

# IAM Roles
module "iam_roles" {
  source = "./modules/iam_roles"
  
  environment = var.environment
  
  roles = [
    {
      name = "eks-node-role"
      policies = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      ]
    },
    {
      name = "eks-cluster-role"
      policies = [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      ]
    }
  ]
}

# CloudWatch Monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-renewable-energy-platform"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "asset-service"],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "asset-service"],
            ["AWS/ECS", "CPUUtilization", "ServiceName", "telemetry-service"],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "telemetry-service"]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Service Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", "Telemetry"],
            ["AWS/DynamoDB", "UserErrors", "TableName", "Telemetry"],
            ["AWS/DynamoDB", "SystemErrors", "TableName", "Telemetry"]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "DynamoDB Performance"
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "High CPU utilization in ECS services"
  
  dimensions = {
    ServiceName = "asset-service"
  }
  
  alarm_actions = [var.sns_topic_arn]
}

# Outputs
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "aurora_cluster_endpoint" {
  value = module.aurora.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}