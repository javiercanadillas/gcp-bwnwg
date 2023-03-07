locals {
  service_account_id = base64encode("$(var.cluster_name)-sa")
}

# New project, remember to authenticate with gcloud auth application-default
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Enable OS login in the project
resource "google_compute_project_metadata_item" "metadata_os_login" {
  key   = "enable-oslogin"
  value = "true"
}

# Enable the required services needed for execution
resource "google_project_service" "enabled_services" {
  project = var.project
  service = each.key
  for_each = toset([
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "sourcerepo.googleapis.com",
    "spanner.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudfunctions.googleapis.com",
    "workflows.googleapis.com",
    "eventarc.googleapis.com",
  "pubsub.googleapis.com"])
  disable_on_destroy = false
}

# Create Spanner Instance and Database
resource "google_spanner_instance" "oms" {
  name         = var.spanner_instance_name
  config       = "regional-$(var.region)"
  display_name = "Main OMS instance"
  num_nodes    = 1
}

resource "google_spanner_database" "ordersdb" {
  instance = google_spanner_instance.oms.name
  name     = var.spanner_db_name
  ddl = [<<EOF
    "CREATE TABLE Orders (
      OrderId STRING(36) NOT NULL,
      ProductId INT64 NOT NULL,
      CustomerId INT64 NOT NULL,
      Quantity INT64,
      OrderDate TIMESTAMP NOT NULL OPTIONS(allow_commit_timestamp=true),
      FulfillmentHub STRING(3),
      LastUpdateZone String(20),
      LastUpdateTime TIMESTAMP NOT NULL OPTIONS(allow_commit_timestamp=true),
      Status STRING(20),
    ) PRIMARY KEY(OrderId);"
    EOF
  ]
}
