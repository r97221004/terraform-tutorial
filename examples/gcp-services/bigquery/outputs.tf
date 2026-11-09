output "orders_table" {
  description = "The orders table, as bq expects it: dataset.table."
  value       = "${google_bigquery_dataset.shop.dataset_id}.${google_bigquery_table.orders.table_id}"
}

output "view" {
  description = "The daily revenue view, as dataset.table."
  value       = "${google_bigquery_dataset.shop.dataset_id}.${google_bigquery_table.daily_revenue.table_id}"
}
