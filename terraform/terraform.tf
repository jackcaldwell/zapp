provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

locals {

}

resource "aws_ecs_cluster" "main" {
  name = "${var.resource_prefix}-cluster"
}

# VPC Definition
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.70.0"

  name = "${var.resource_prefix}-vpc"
  cidr = "10.50.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  public_subnets  = ["10.50.11.0/24", "10.50.12.0/24"]
  private_subnets = ["10.50.21.0/24", "10.50.22.0/24"]

  single_nat_gateway = true

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true

  tags = {
    Terraform = "true"
  }
}


module "zapp" {
  source  = "aoggz/fargate-app/aws"
  version = "2.0.0"

  resource_prefix                           = var.resource_prefix
  ecs_cluster_id                            = aws_ecs_cluster.cluster.id
  acm_certificate_domain                    = var.acm_certificate_domain
  log_retention_in_days                     = 30
  app_domain                                = var.app_domain           # must be a subdomain of the acm_certificate_domain
  route53_hosted_zone_id                    = var.hosted_zone_id       # Route 53 hosted zone id in which alias to load balancer
  task_count                                = var.app_instance_count   # Number of instances to run
  reverse_proxy_cpu                         = var.reverse_proxy_cpu    # Number of CPU Units for reverse_proxy container
  reverse_proxy_memory                      = var.reverse_proxy_memory # MB of RAM for reverse_proxy container
  reverse_proxy_version                     = "1.0.0"                  # Docker image tag of nginx_reverse_proxy container
  reverse_proxy_cert_state                  = "Lancashire"
  reverse_proxy_cert_locality               = "Preston"
  reverse_proxy_cert_organization           = "Okount"
  reverse_proxy_cert_organizational_unit    = "-"
  reverse_proxy_cert_email_address          = "jack@okount.com"
  xray_cpu                                  = var.xray_cpu    # Number of CPU Units for xray container
  xray_memory                               = var.xray_memory # MB of RAM for xray container
  alb_internal                              = true
  alb_subnets_public                        = var.public_subnet_ids
  alb_subnets_private                       = var.private_subnet_ids
  alb_listener_default_action               = "redirect" # Note: if redirect is used, another lb_listener_rule must be created that forwards to the target group
  alb_listener_default_redirect_host        = var.redirect_host
  alb_listener_default_redirect_port        = "443"
  alb_listener_default_redirect_protocol    = "HTTPS"
  alb_listener_default_redirect_status_code = "HTTP_302"
  vpc_id                                    = var.vpc_id
  web_cpu                                   = var.web_cpu     # Number of CPU Units for web container
  web_memory                                = var.web_memory  # MB of RAM for web container
  web_image                                 = var.web_image   # Name of Docker image to use for web container
  web_version                               = var.web_version # Version of Docker image to use for web container
  web_environment_variables = [
    {
      name  = "ASPNETCORE_ENVIRONMENT",
      value = var.aspnetcore_environment,
    },
  ]
}

