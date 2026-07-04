resource "aws_s3_bucket" "backup-util-fede-dev-infrastructure" {
  bucket = "backup-util-fede-dev-infrastructure"
}

resource "aws_iam_user" "backup-util-writer" {
  name = "backup-util-writer-fedebrick"
}

data "aws_iam_policy_document" "backup_util_policy_fedebrick" {
  statement {
    effect = "Allow"
    actions = [ "s3:ListBucket" ]
    resources = [ aws_s3_bucket.backup-util-fede-dev-infrastructure.arn ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.backup-util-fede-dev-infrastructure.arn}/fedebrick/*",
      "${aws_s3_bucket.backup-util-fede-dev-infrastructure.arn}"
    ]
  }
}

resource "aws_iam_user_policy" "backup_util_policy" {
  name = "backup_util_policy_fedebrick"
  user = aws_iam_user.backup-util-writer.name
  policy = data.aws_iam_policy_document.backup_util_policy_fedebrick.json
}
