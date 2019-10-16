provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     ="${var.region}"
}

data "alicloud_oss_buckets" "oss_buckets_ds" {
 # name_regex = "nike-vm-images-shanghai"
 name_regex = "vm-image-test"
}

output "first_oss_bucket_name" {
  value = "${data.alicloud_oss_buckets.oss_buckets_ds.buckets.0.name}"
}

resource "alicloud_oss_bucket_object" "object-source" {
  bucket = "${data.alicloud_oss_buckets.oss_buckets_ds.buckets.0.name}"
  key    = "win2016.vhd"
  source = "C:/ReferenceImages/REFW2K16SE-1.0.5.190917/REFW2K16SE-1.0.5.190917.vhd"
}