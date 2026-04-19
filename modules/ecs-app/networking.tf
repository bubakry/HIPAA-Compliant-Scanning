resource "aws_security_group" "alb" {
  count = local.service_enabled ? 1 : 0

  name        = "${local.name_prefix}-alb-sg"
  description = "Restricts ALB access to approved HTTPS clients."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    },
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = local.service_enabled ? toset(var.allowed_alb_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.alb[0].id
  description       = "Approved client HTTPS ingress"
  cidr_ipv4         = each.value
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_security_group" "app" {
  count = local.service_enabled ? 1 : 0

  name        = "${local.name_prefix}-app-sg"
  description = "Allows only ALB ingress and private encrypted egress for ECS tasks."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-sg"
    },
  )
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  count = local.service_enabled ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  description                  = "Forward HTTPS traffic to the ECS tasks."
  from_port                    = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app[0].id
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  count = local.service_enabled ? 1 : 0

  security_group_id            = aws_security_group.app[0].id
  description                  = "Only the ALB can reach the FastAPI tasks."
  from_port                    = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb[0].id
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "app_https_private" {
  count = local.service_enabled ? 1 : 0

  security_group_id = aws_security_group.app[0].id
  description       = "Private HTTPS egress to VPC endpoints."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "app_to_database" {
  count = local.service_enabled ? 1 : 0

  security_group_id = aws_security_group.app[0].id
  description       = "Private PostgreSQL egress."
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.db_port
  ip_protocol       = "tcp"
  to_port           = var.db_port
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  count = local.service_enabled ? 1 : 0

  security_group_id            = var.db_security_group_id
  description                  = "Only ECS tasks can reach the encrypted database."
  from_port                    = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app[0].id
  to_port                      = var.db_port
}
