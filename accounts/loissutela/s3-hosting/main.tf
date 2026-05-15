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
  aliases             = ["loissutela.art", "www.loissutela.art"]

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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
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
    acm_certificate_arn      = aws_acm_certificate_validation.loissutela_art.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
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

resource "aws_acm_certificate" "loissutela_art" {
  provider                  = aws.us_east_1
  domain_name               = "loissutela.art"
  subject_alternative_names = ["www.loissutela.art"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "loissutela_art_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.loissutela_art.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.loissutela_art.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "loissutela_art" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.loissutela_art.arn
  validation_record_fqdns = [for r in aws_route53_record.loissutela_art_cert_validation : r.fqdn]
}

resource "aws_cloudfront_function" "redirect_www_to_apex" {
  name    = "loissutela-art-redirect-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "301 redirect www.loissutela.art to loissutela.art"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var host = request.headers.host && request.headers.host.value;
      if (host === 'www.loissutela.art') {
        var qs = '';
        if (request.querystring) {
          var parts = [];
          for (var k in request.querystring) {
            var v = request.querystring[k];
            if (v.multiValue) {
              for (var i = 0; i < v.multiValue.length; i++) {
                parts.push(k + '=' + v.multiValue[i].value);
              }
            } else {
              parts.push(k + '=' + v.value);
            }
          }
          if (parts.length > 0) { qs = '?' + parts.join('&'); }
        }
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: { value: 'https://loissutela.art' + request.uri + qs },
            'cache-control': { value: 'max-age=3600' }
          }
        };
      }
      return request;
    }
  EOT
}

resource "aws_route53_record" "loissutela_art_apex_a" {
  zone_id = aws_route53_zone.loissutela_art.zone_id
  name    = "loissutela.art"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.loissutela_art_site.domain_name
    zone_id                = aws_cloudfront_distribution.loissutela_art_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "loissutela_art_apex_aaaa" {
  zone_id = aws_route53_zone.loissutela_art.zone_id
  name    = "loissutela.art"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.loissutela_art_site.domain_name
    zone_id                = aws_cloudfront_distribution.loissutela_art_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "loissutela_art_www_a" {
  zone_id = aws_route53_zone.loissutela_art.zone_id
  name    = "www.loissutela.art"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.loissutela_art_site.domain_name
    zone_id                = aws_cloudfront_distribution.loissutela_art_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "loissutela_art_www_aaaa" {
  zone_id = aws_route53_zone.loissutela_art.zone_id
  name    = "www.loissutela.art"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.loissutela_art_site.domain_name
    zone_id                = aws_cloudfront_distribution.loissutela_art_site.hosted_zone_id
    evaluate_target_health = false
  }
}
