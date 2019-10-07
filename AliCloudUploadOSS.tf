provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     ="${var.region}"
}

data "alicloud_oss_buckets" "oss_buckets_ds" {
 # name_regex = "nike-vm-images-shanghai"
}

output "first_oss_bucket_name" {
  value = "${data.alicloud_oss_buckets.oss_buckets_ds.buckets.0.name}"
}

resource "alicloud_oss_bucket_object" "object-source" {
  bucket = "${data.alicloud_oss_buckets.oss_buckets_ds.buckets.0.name}"
  key    = "test"
  source = "C:/temp/1.txt"
}