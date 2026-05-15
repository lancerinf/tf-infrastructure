resource "aws_ssm_parameter" "belle_arti_paintings_s3_uri" {
  name  = "/belle-arti/paintings-s3-uri"
  type  = "String"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "belle_arti_site_s3_uri" {
  name  = "/belle-arti/site-s3-uri"
  type  = "String"
  value = "s3://${aws_s3_bucket.loissutela_art_site.bucket}"
}

resource "aws_s3_bucket" "loissutela_art_site" {
  bucket = "loissutela-art-site-389210"
}

resource "aws_s3_bucket_public_access_block" "loissutela_art_site" {
  bucket                  = aws_s3_bucket.loissutela_art_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "loissutela_art_site" {
  bucket = aws_s3_bucket.loissutela_art_site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "loissutela_art_site" {
  name                              = "loissutela-art-site-oac"
  description                       = "OAC for loissutela.art static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_route53_zone" "loissutela_art" {
  name = "loissutela.art"
}

resource "aws_cloudfront_distribution" "loissutela_art_site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    origin_id                = "s3-loissutela-art-site"
    domain_name              = aws_s3_bucket.loissutela_art_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.loissutela_art_site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-loissutela-art-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

data "aws_iam_policy_document" "loissutela_art_site_bucket" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.loissutela_art_site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.loissutela_art_site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "loissutela_art_site" {
  bucket = aws_s3_bucket.loissutela_art_site.id
  policy = data.aws_iam_policy_document.loissutela_art_site_bucket.json
}
