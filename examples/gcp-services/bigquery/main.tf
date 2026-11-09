# A dataset with one table and one view. Terraform owns the structure:
# the dataset, the table's schema, and the view's SQL. The rows are loaded
# with bq, outside Terraform.

resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_bigquery_dataset" "shop" {
  project     = google_project_service.bigquery.project
  dataset_id  = "shop" # letters, digits, and underscores only
  location    = var.region
  description = "BigQuery chapter's sample orders."

  # Lab only: lets terraform destroy delete the dataset even with tables in it.
  delete_contents_on_destroy = true
}

resource "google_bigquery_table" "orders" {
  dataset_id = google_bigquery_dataset.shop.dataset_id
  table_id   = "orders"
  schema     = file("${path.module}/schema/orders.json")

  # Lab only: while this is true (the default), Terraform refuses to delete
  # the table, including when a schema change would replace it.
  deletion_protection = false
}

# A view is a saved query. It stores no data; it reads orders each time.
resource "google_bigquery_table" "daily_revenue" {
  dataset_id = google_bigquery_dataset.shop.dataset_id
  table_id   = "daily_revenue"

  deletion_protection = false

  view {
    use_legacy_sql = false
    query          = <<-SQL
      SELECT order_date, COUNT(*) AS orders, SUM(amount) AS revenue
      FROM `${google_bigquery_table.orders.project}.${google_bigquery_table.orders.dataset_id}.${google_bigquery_table.orders.table_id}`
      GROUP BY order_date
    SQL
  }
}
