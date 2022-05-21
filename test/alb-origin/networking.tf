data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "example" {
  name = "alb_security_group"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "cf-http"
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  ingress {
    description = "cf-https"
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.42.0/8"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "cloudfront" {
  route_table_id = aws_vpc.main.main_route_table_id
  destination_prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id
  gateway_id = aws_internet_gateway.main
}

resource "aws_lb" "origin_lb" {
  name = "test-lb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.example.id]
  subnet = aws_subnet.main
}

# resource "aws_lb_target_group" "group" {
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id
# }