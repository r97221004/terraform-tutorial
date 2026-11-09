# A public web service on Cloud Run, from Google's sample container. It
# scales to zero when idle and runs as its own service account.

resource "google_project_service" "enabled" {
  for_each = toset(["run.googleapis.com", "iam.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

# The service's identity. It has no roles: the sample calls no Google APIs.
resource "google_service_account" "hello" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "hello-run"
  display_name = "Cloud Run chapter hello service"
}

resource "google_cloud_run_v2_service" "hello" {
  project  = google_project_service.enabled["run.googleapis.com"].project
  name     = "hello"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL" # reachable from the internet

  # Lab only: while this is true (the default), Terraform refuses to destroy
  # the service.
  deletion_protection = false

  # Everything in template is a revision: changing any of it creates a new one.
  template {
    # null: Cloud Run names each revision. A name lets traffic point at it,
    # and can't be reused for a different template.
    revision        = var.revision
    service_account = google_service_account.hello.email

    scaling {
      min_instance_count = 0 # scale to zero when idle
      max_instance_count = 2 # a ceiling on cost
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "MESSAGE"
        value = var.message
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # With a resources block, this must be set to keep request-based
        # billing: CPU only while a request is being handled.
        cpu_idle = true
      }
    }
  }

  # One traffic block per revision in var.traffic. With none (the default),
  # all traffic goes to the latest revision the moment it's ready.
  dynamic "traffic" {
    for_each = var.traffic

    content {
      type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
      revision = traffic.key
      percent  = traffic.value
      tag      = traffic.key # https://hello-v2---hello-….run.app (3-47 characters)
    }
  }
}

# Anyone may call the service: allUsers gets the invoker role on it.
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.hello.project
  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
