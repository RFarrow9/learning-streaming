terraform {
  backend "s3" {
    bucket = "robf-terraform"
    dynamodb_table = "terraform-locks"
    region         = "eu-west-1"
    key            = "streaming/terraform.state"
  }
}
## SET PROVIDERS
provider "aws" {
  profile = "default"
  region = "eu-west-1"
}


#resource "aws_iot_thingt" "router" {
#  name = "router"
#  attribute
#}


resource "aws_kinesis_stream" "stream" {
  name             = "stream"
  shard_count      = 1
  retention_period = 48

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Environment = "test"
  }
}
#resource "aws_kinesis_stream_consumer" "example" {
#  name       = "s3-consumer"
#  stream_arn = aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn
#}
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-test-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn

#    processing_configuration {
#      enabled = "true"
#
#      processors {
#        type = "Lambda"
#
#        parameters {
#          parameter_name  = "LambdaArn"
#          parameter_value = "${module.lambda_function.lambda_function_arn}:$LATEST"
#        }
#      }
#    }
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "robf-streaming-bucket"
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  inline_policy {
    name = "s3_bucket_access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:*"]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = ["s3:*"]
          Effect   = "Allow"
          Resource = [
            "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*",
            "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}"
          ]
        },
      ]
    })
  }
}
resource "aws_iam_role" "fleetwise_role" {
  name = "fleetwise_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "iotfleetwise.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  inline_policy {
    name = "s3_bucket_access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["timestream:*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

}



resource "aws_iam_role" "lambda_iam" {
  name = "lambda_iam"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  timeout = 120
  function_name = "streamer"
  description   = "streams data"
  handler       = "main.lambda_handler"
  runtime       = "python3.8"

  source_path = "./main.py"

  tags = {
    Name = "my-lambda1"
  }
}