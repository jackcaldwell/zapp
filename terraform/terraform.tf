provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

locals {
  # The name of the ECR cluster to be created
  aws_ecr_repository_name = var.aws_resource_prefix
  # The name of the ECS cluster to be created
  aws_ecs_cluster_name = "${var.aws_resource_prefix}-cluster"
  # The name of the ECS service to be created
  aws_ecs_service_name = "${var.aws_resource_prefix}-service"
  # The name of the application load balancer to be created
  aws_lb_name = "${var.aws_resource_prefix}-load-balancer"
  # The base name for the target groups to be created
  aws_target_group_name = "${var.aws_resource_prefix}-target-group"
}

resource "aws_ecr_repository" "app_repository" {
  name = local.aws_ecr_repository_name
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = var.aws_resource_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = file("task-definitions/service.json")
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.aws_ecs_cluster_name
}

resource "aws_vpc" "main" {
  cidr_block         = "10.0.0.0/16"
  enable_dns_support = true
}

resource "aws_internet_gateway" "main" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
}

resource "aws_subnet" "a" {
  depends_on        = [aws_vpc.main]
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "b" {
  depends_on        = [aws_vpc.main]
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}b"
}

resource "aws_security_group" "main" {
  name       = "${var.aws_resource_prefix}-sg"
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  protocol          = "-1"
  to_port           = 0
  from_port         = 0
  security_group_id = aws_security_group.main.id
  self              = false
  cidr_blocks       = ["10.0.0.0/24", "10.0.1.0/24"]
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  protocol          = "-1"
  to_port           = 0
  from_port         = 0
  security_group_id = aws_security_group.main.id
  self              = false
  cidr_blocks       = ["10.0.0.0/24", "10.0.1.0/24"]
}


resource "aws_lb" "main" {
  name               = local.aws_lb_name
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.a.id, aws_subnet.b.id]
  security_groups    = [aws_security_group.main.id]
  depends_on         = [aws_subnet.a, aws_subnet.b, aws_security_group.main]
}

resource "aws_lb_target_group" "instance" {
  name     = "${local.aws_target_group_name}-instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "ip" {
  name        = "${local.aws_target_group_name}-ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip.arn
  }
}

resource "aws_ecs_service" "ecs_service" {
  name            = local.aws_ecs_service_name
  task_definition = "${var.aws_resource_prefix}:${aws_ecs_task_definition.task_definition.revision}"
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on      = [aws_lb.main, aws_lb_target_group.ip]
  network_configuration {
    subnets         = [aws_subnet.a.id, aws_subnet.b.id]
    security_groups = [aws_security_group.main.id]
  }
  cluster = local.aws_ecs_cluster_name
  load_balancer {
    container_name   = "app"
    container_port   = 80
    target_group_arn = aws_lb_target_group.ip.arn
  }
}
