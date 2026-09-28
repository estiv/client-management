# Design-time Terraform for the Client Management application (demo only).
# Scope 1 parses this file. Nothing here is applied to a live account.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_vpc" "main" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name        = "client-management"
    Application = "client-management"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = ["us-east-1a", "us-east-1b"][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "client-management-public-${count.index}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = ["us-east-1a", "us-east-1b"][count.index]

  tags = {
    Name = "client-management-private-${count.index}"
    Tier = "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "client-management"
  }
}

resource "aws_security_group" "alb" {
  name        = "client-management-alb"
  description = "Internet-facing entry for Client Management"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "api" {
  name   = "client-management-api"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "API traffic from the load balancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "client-db"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Postgres from client-management-api"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }
}

resource "aws_lb" "alb" {
  name               = "client-management-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "alb"
  }
}

resource "aws_lb_target_group" "client_api" {
  name        = "client-management-api"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/demo"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.client_api.arn
  }
}

resource "aws_ecs_cluster" "main" {
  name = "client-management"
}

resource "aws_ecs_task_definition" "client_management_api" {
  family                   = "client-management-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "client-management-api"
      image = "public.ecr.aws/docker/library/nginx:1.27-alpine"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.client_db.address
        },
        {
          name  = "DATABASE_NAME"
          value = aws_db_instance.client_db.db_name
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "client_management_api" {
  name            = "client-management-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.client_management_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.api.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.client_api.arn
    container_name   = "client-management-api"
    container_port   = 8080
  }
}

resource "aws_db_subnet_group" "client_db" {
  name       = "client-db"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "client_db" {
  identifier             = "client-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "clientdb"
  username               = "clientadmin"
  password               = var.db_password
  storage_encrypted      = true
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.client_db.name
  skip_final_snapshot    = true

  tags = {
    Name = "client-db"
  }
}
