resource "google_storage_bucket" "terraform_state" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 30
    }
  }
}

output "bucket_url" {
  value = google_storage_bucket.terraform_state.url
}

terraform {
  backend "gcs" {
    bucket = "backend_bucket_capstone12"
    prefix = "terraform/state"
  }
}