terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
  backend "s3" {
    bucket  = "bhcrc-tfstate"
    key     = "hangman.tfstate"
    region  = "us-east-1"
    profile = "terraform"

  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "terraform"
}

# Resources created in AWS Console before using this Terraform Configuration: #
# -- ACM Certificate for my API Gateway Custom Domain ------------------------#
# -- ECR private repo with my app container ----------------------------------#

data "aws_api_gateway_domain_name" "api-domain" {
  domain_name = var.api-domain-name
}

data "aws_acm_certificate" "cert" {
  domain = "hangman-alb.brettmhowell.com"
  statuses = ["ISSUED"]
}

#----------------------------------------------------------#
#--------------------------VPC-----------------------------#
#----------------------------------------------------------#
# VPC will use a /23 prefix for a total of 512 IP's in     #
# the VPC. The subnets will use a /27 prefix for 32 IP's   #
# in each subnet. This will allow for a total of 16        #
# subnets. We will start by creating 4 (2 Public and 2     #
# Private), which should leave sufficient room for         #
# expansion if necessary. ---------------------------------#
#----------------------------------------------------------#

resource "aws_vpc" "vpc" {
  cidr_block           = "10.16.0.0/23"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "hangman-vpc-tf"
  }
}

#--------------------Internet-Gateway----------------------#

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "hangman-igw-tf"
  }
}

#---------------------Public-Subnets-----------------------#
# Creates public subnets with a route to the internet      #
# gateway. These subnets will host my ECS Fargate Cluster. #
#----------------------------------------------------------#

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.0/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.32/27"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

#----------------Public Subnet Route Table-----------------#

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public_rt_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_rt_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

#---------------------Private-Subnets-----------------------#
#- Creates Private Subnets that will host the ECS Cluster.  #
#-----------------------------------------------------------#

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.128/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.16.0.160/27"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-2"
  }
}

#----------------Private Subnet Route Table----------------#

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "private_rt_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rt_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

#-------------------Security-Groups-----------------------#
#- Creates the Security Groups Necessary for the ---------#
#- configuration to communicate properly -----------------#
#---------------------------------------------------------#

#-------------Application-Load-Balancer-SG----------------#
#- Any Traffic -> ALB ------------------------------------#
#- Local       -> ALB ------------------------------------#
#- VPC Link    -> ALB ------------------------------------#
#- ALB         -> Elastic Container Service --------------#
#---------------------------------------------------------#

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg-tf"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "alb-ingress-from-internet" {
  security_group_id = aws_security_group.alb-sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description = "Any Traffic to ALB"
}

resource "aws_security_group_rule" "ingress-from-vpc" {
  security_group_id = aws_security_group.alb-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["10.16.0.0/23"]
  description = "Local to ALB"
}

resource "aws_security_group_rule" "egress-to-ecs" {
  security_group_id        = aws_security_group.alb-sg.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs-sg.id
  description = "ALB to Elastic Container Service"
}

#--------------Elastic-Container-Service-SG---------------#
#- ALB -> ECS --------------------------------------------#
#- ECS -> ECS --------------------------------------------#
#- ECS -> ALB --------------------------------------------#
#- ECS -> RDS --------------------------------------------#
#- ECS -> Anywhere ---------------------------------------#
#---------------------------------------------------------#

resource "aws_security_group" "ecs-sg" {
  name        = "ecs-sg-tf"
  description = "Security group for the ECS Cluster"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-from-alb" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "ALB to ECS"
}

resource "aws_security_group_rule" "ecs-ecs" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs-sg.id
  description = "ECS to ECS"
}

resource "aws_security_group_rule" "ecs-egress-to-alb" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb-sg.id
  description = "ECS to ALB"
}

resource "aws_security_group_rule" "egress-to-rds" {
  security_group_id        = aws_security_group.ecs-sg.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds-sg.id
  description              = "ECS to RDS (MySQL)"
}

resource "aws_security_group_rule" "egress-to-anywhere" {
  security_group_id = aws_security_group.ecs-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description = "ECS to Anywhere"
}

#------------------------RDS-SG--------------------------#
#- ECS -> RDS (MySQL) -----------------------------------#
#--------------------------------------------------------#

resource "aws_security_group" "rds-sg" {
  name        = "rds-sg-tf"
  description = "Security group for the RDS Instance"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ingress-from-ecs" {
  security_group_id        = aws_security_group.rds-sg.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs-sg.id
  description              = "ECS to RDS (MySQL)"
}

#----------------------------RDS---------------------------#

resource "aws_db_instance" "mysql_db" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
  publicly_accessible  = false
  skip_final_snapshot  = true
  multi_az             = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "hangman"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "Hangman DB subnet group"
  }
}

#----------------Application-Load-Balancer-----------------#
# Creates the Target Group that will point towards the ECS #
# Cluster and the Application Load Balancer that sends ----#
# traffic to the target group, listening in HTTP:80 -------#
#----------------------------------------------------------#

resource "aws_lb_target_group" "target-group" {
  name        = var.tg-name
  port        = var.container-port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb" "alb" {
  name               = var.alb-name
  internal           = false
  load_balancer_type = "application"

  subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups = [aws_security_group.alb-sg.id]
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

#-----------------Elastic-Container-Service-----------------#
#- Creates an ECS Cluster for the app to run in aswell as:  #
#- TASK DEFINITION - Pulls image from ECR Repo, defines the #
#- compute resources that will be used and exposes the port #
#- SERVICE - Specifies the amount of tasks to run, Attaches #
#- the ALB and defines the network to run in. --------------#
#- AUTO-SCALING - Puts the service in an auto scaling group #
#- that can expand from 1-4 tasks based on CPU Utilization -#
#-----------------------------------------------------------#

resource "aws_ecs_cluster" "cluster" {
  name = "Hangman-Cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "hangman-log-group"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "hangman-log-stream"
  log_group_name = aws_cloudwatch_log_group.log_group.name
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "Hangman-TaskDefinition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.execution-role-arn
  execution_role_arn       = var.execution-role-arn
  cpu                      = 256
  memory                   = 512

  container_definitions = <<DEFINITION
  [
    {
      "name": "${var.container-name}",
      "image": "${var.container-uri}",
      "essential": true,
      "portMappings": [
        {
          "protocol": "tcp",
          "appProtocol": "http",
          "containerPort": ${var.container-port},
          "hostPort": ${var.container-port}
        }
      ],
      "environment": [
        {
          "name": "MYSQL_HOST",
          "value": "${aws_db_instance.mysql_db.address}"
        },
        {
          "name": "MYSQL_USER",
          "value": "${aws_db_instance.mysql_db.username}"
        },
        {
          "name": "MYSQL_PASSWORD",
          "value": "${aws_db_instance.mysql_db.password}"
        },
        {
          "name": "MYSQL_DB",
          "value": "${aws_db_instance.mysql_db.db_name}"
        },
        {
          "name": "SECRET_KEY",
          "value": "${var.db_secret_key}"
        },
        {
          "name": "USER_POOL_ID",
          "value": "${aws_cognito_user_pool.main.id}"
        },
        {
          "name": "CLIENT_ID",
          "value": "${aws_cognito_user_pool_client.client.id}"
        }
      ],

      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:${var.container-port}/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 0
      },

      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.log_group.name}",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "service" {
  name = var.service-name
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task_definition.id
  desired_count = 1
  launch_type = "FARGATE"
  
  deployment_circuit_breaker {
    enable = true
    rollback = true
  }

  network_configuration {
    security_groups = [aws_security_group.ecs-sg.id]
    subnets = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target-group.arn
    container_name = var.container-name
    container_port = var.container-port
  }
}

resource "aws_appautoscaling_target" "auto_scaling" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "auto_scaling_policy" {
  name               = "Hangman-AutoScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auto_scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.auto_scaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auto_scaling.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

#-------------------------Cognito---------------------------#

data "aws_ses_domain_identity" "example" {
  domain = "brettmhowell.com"
}

resource "aws_ses_email_identity" "ses_email_identity" {
  email = "noreply@brettmhowell.com"
}

resource "aws_iam_role" "cognito_ses" {
  name = "CognitoSESSendingRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect  = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
        Action  = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy" "cognito_ses" {
  name = "CognitoSESSendingPolicy"
  role = aws_iam_role.cognito_ses.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cognito_user_pool" "main" {
  name = "hangman_user_pool"

  username_attributes = ["email"]

  schema {
    attribute_data_type = "String"
    name = "email"
    required = true
    mutable = true
    developer_only_attribute = false
  }

  schema {
    attribute_data_type = "String"
    name = "preferred_username"
    required = true
    mutable = true
    developer_only_attribute = false
  }

  password_policy {
    minimum_length = 8
    require_lowercase = false
    require_numbers = false
    require_symbols = false
    require_uppercase = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  auto_verified_attributes = ["email"]

  email_configuration {
    source_arn = aws_ses_email_identity.ses_email_identity.arn
    email_sending_account = "DEVELOPER"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "hangman_user_pool_client"

  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}
