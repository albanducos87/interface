terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"

  backend "s3" {
    bucket         = "s3-1t21-ce-business-monitoring-prod"
    key            = "1t21-ce-business-monitoring-prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "dynamodb-1t21-ce-business-monitoring-prod-terraform-lock"
    profile        = "role-1t21-eu-west-1-infraAdminAccess"

  }
}

provider "aws" {
  profile = var.role_admin_profile
  region  = "eu-west-1"
}

#tfsec:ignore:aws-ec2-enforce-http-token-imds Because we suspects it blocks proper registration of bastion
resource "aws_instance" "monitoring_frontend" {
  ami                  = data.aws_ami.latest_redhat7_ami.id
  instance_type        = "t3.xlarge"
  subnet_id            = var.subnet_private_a_id
  availability_zone    = "eu-west-1a"
  iam_instance_profile = aws_iam_instance_profile.frontend.name
  # iam_instance_profile = "profile-instance-mandatory-permissions" // Default PCP mandatory instance profile
  user_data = file("user_data.sh")

  vpc_security_group_ids = [
    var.pcp_mandatory_security_group_id,
    var.pcp_allow_airbus_lan_group_id,
    var.pcp_allow_airbus_lan_https_group_id,
    var.vpc_default_security_group_id,
    aws_security_group.web_traffic.id
  ]

  root_block_device {
    encrypted  = true
    kms_key_id = var.kms_key_arn
    tags       = merge({ Name = "monitoring frontend os", }, local.common_tags)
  }

  tags = merge({ Name = local.namespace, "platform:ec2:scheduling:autostop" = "false" }, local.common_tags)

}

resource "aws_ebs_volume" "frontend_data" {
  availability_zone = "eu-west-1a"
  size              = 30
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = merge({ Name = "monitoring frontend data", }, local.common_tags)
}

resource "aws_volume_attachment" "frontend_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.frontend_data.id
  instance_id = aws_instance.monitoring_frontend.id
}

resource "aws_route53_record" "frontend" {
  zone_id = var.route53_zone_id
  name    = var.frontend_dns_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.monitoring_frontend.private_ip]
}

data "aws_ami" "latest_redhat7_ami" {
  most_recent = true
  owners      = ["003920101472"]

  filter {
    name   = "name"
    values = ["ami-airbus-pcp-redhat7-release-*"]
  }

  filter {
    name   = "tag:pcp:ami:validated"
    values = ["true"]
  }
}

data "aws_ami" "latest_amazonlinux2_ami" {
  most_recent = true
  owners      = ["003920101472"]

  filter {
    name   = "name"
    values = ["ami-airbus-pcp-amazonlinux2-release-*"]
  }

  filter {
    name   = "tag:pcp:ami:validated"
    values = ["true"]
  }
}

#tfsec:ignore:aws-vpc-no-public-ingress-sgr Because we are openning to specific LAN CIDRs on purpose
#tfsec:ignore:aws-vpc-no-public-egress-sgr Because we are openning to specific LAN CIDRs on purpose
#tfsec:ignore:aws-vpc-add-description-to-security-group-rule Because theses standard rules are self-explantory
resource "aws_security_group" "web_traffic" {
  name        = "${local.namespace}-web-frontend"
  description = "Allow 80 and 443 inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.all-lan-cidrs
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.all-lan-cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.all-lan-cidrs
  }

  tags = merge({ Name = "web_traffic" }, local.common_tags)
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key we do not have a suitable key to be used with log groups and its a low severity anyway.
resource "aws_cloudwatch_log_group" "deployment_logs" {
  name              = "/aws/business-monitoring/${var.environment}"
  retention_in_days = 30
  tags              = local.common_tags
}
