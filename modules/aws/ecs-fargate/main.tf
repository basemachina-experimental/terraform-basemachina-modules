# BaseMachina Bridge ECS Fargate Module
#
# このモジュールは機能別ファイル分割パターンを採用しています。
# 全てのリソース定義は責任ごとに以下のファイルに配置されています：
#
# - alb.tf: Application Load Balancer、ターゲットグループ、リスナー
# - ecs.tf: ECSクラスター、タスク定義、ECSサービス
# - security_groups.tf: セキュリティグループとルール
# - iam.tf: IAMロールとポリシー
# - logs.tf: CloudWatch Logsロググループ
# - variables.tf: 入力変数定義
# - outputs.tf: 出力値定義
#
# main.tfは意図的に空のまま維持されています。
