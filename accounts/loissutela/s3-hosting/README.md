# loissutela/s3-hosting

Static website hosting for [loissutela.art](https://loissutela.art) on AWS.

## Traffic flow

```
Browser
  │
  │  DNS lookup: loissutela.art / www.loissutela.art
  ▼
Route 53 (hosted zone: loissutela.art)
  │  A + AAAA alias records → CloudFront
  │
  ▼
CloudFront distribution  (PriceClass_100, eu-north-1 + nearby edges)
  │
  ├─ Viewer request: CloudFront Function (viewer-request-router)
  │    ├─ host == www.loissutela.art  →  301 to https://loissutela.art<uri>
  │    └─ apex requests
  │         ├─ uri ends with /          →  rewrite to <uri>index.html
  │         ├─ last segment has no .   →  rewrite to <uri>/index.html
  │         └─ otherwise               →  pass through unchanged
  │
  ├─ HTTPS only  (viewer_protocol_policy = redirect-to-https)
  │   TLS: ACM certificate (us-east-1), SNI-only, TLSv1.2_2021 minimum
  │
  ├─ Cache: managed CachingOptimized policy
  │
  ├─ Error handling
  │    ├─ 403 → /index.html (200)   ─┐ safety net for any paths that
  │    └─ 404 → /index.html (200)   ─┘ still slip past the function
  │
  └─ Origin request (OAC, SigV4-signed)
       │
       ▼
     S3 bucket: loissutela-art-site-389210  (eu-north-1)
       Private (all public access blocked, BucketOwnerEnforced)
       Bucket policy: allows s3:GetObject only from this distribution
```

## Resources

| Resource | Name / ID | Notes |
|---|---|---|
| `aws_s3_bucket` | `loissutela-art-site-389210` | Site content; private, OAC access only |
| `aws_s3_bucket` | `loissutela-art-paintings-389210` | Paintings asset store; private, versioning enabled |
| `aws_cloudfront_origin_access_control` | `loissutela-art-site-oac` | SigV4 signing for S3 origin |
| `aws_cloudfront_distribution` | — | Aliases: `loissutela.art`, `www.loissutela.art` |
| `aws_cloudfront_function` | `loissutela-art-viewer-request-router` | www→apex redirect + directory index rewrite |
| `aws_acm_certificate` | `loissutela.art` + SAN `www.loissutela.art` | Issued in us-east-1 (CloudFront requirement) |
| `aws_route53_zone` | `loissutela.art` | Public hosted zone |
| `aws_route53_record` | A + AAAA for apex and www | Alias to CloudFront |
| `aws_ssm_parameter` | `/belle-arti/paintings-s3-uri` | `s3://loissutela-art-paintings-389210` |
| `aws_ssm_parameter` | `/belle-arti/site-s3-uri` | `s3://loissutela-art-site-389210` |

## Deploying changes

```bash
# from this directory
terraform init   # only needed after provider changes
terraform plan
terraform apply
```

After changes that affect CloudFront behaviour (function code, cache policy, error responses), invalidate the edge cache:

```bash
aws --profile loissutela cloudfront create-invalidation \
  --distribution-id E2HN9XKFRXUJY6 --paths '/*'
```

## Notes

- The ACM certificate must live in `us-east-1` regardless of the rest of the stack being in `eu-north-1`. A dedicated `aws.us_east_1` provider alias is defined in `providers.tf` for this reason.
- The CloudFront Function rewrites bare directory paths (e.g. `/gallery`) to `/gallery/index.html` before they reach S3, because the REST origin (unlike an S3 website endpoint) does not resolve directory indexes automatically.
- The paintings bucket URI is published to SSM so the `belle-arti` application can discover it at runtime without hardcoding the bucket name.
