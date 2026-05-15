terraform {
  required_version = ">= 1.11.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.93.0"
    }
  }

  backend "s3" {
    bucket = "tf-infrastructure-fede-dev-389210"
    key = "accounts/loissutela/s3-hosting.tfstate"
    region = "eu-north-1"
    use_lockfile = true
    profile      = "fede-dev"
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "loissutela"
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "loissutela"
}
