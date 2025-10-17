# ========================================
# タスク実行ロール (Task Execution Role)
# ========================================
# ECS Fargateがタスクを起動する際に必要な権限を提供
# - ECRイメージのpull
# - CloudWatch Logsへの書き込み

resource "aws_iam_role" "task_execution" {
  name_prefix = "${var.name_prefix}-bridge-execution-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# AmazonECSTaskExecutionRolePolicyマネージドポリシーのアタッチ
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# AmazonEC2ContainerRegistryReadOnlyマネージドポリシーのアタッチ
# ECR (プライベート/パブリック) からイメージをpullするために必要
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# CloudWatch Logsへの書き込み権限を持つインラインポリシー
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.bridge.arn}:*"
      }
    ]
  })
}

# ========================================
# タスクロール (Task Role)
# ========================================
# Bridgeコンテナ内のアプリケーションがAWSサービスにアクセスする際の権限を提供
# 現時点では最小権限（将来的な拡張用）

resource "aws_iam_role" "task" {
  name_prefix = "${var.name_prefix}-bridge-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}
