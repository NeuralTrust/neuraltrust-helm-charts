gcloud iam service-accounts create clickhouse-cluster

gsutil iam ch serviceAccount:clickhouse-cluster@neuraltrust-app-prod.iam.gserviceaccount.com:roles/storage.objectViewer gs://neuraltrust-clickhouse-backup-prod


gcloud iam service-accounts add-iam-policy-binding clickhouse-cluster@neuraltrust-app-prod.iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:neuraltrust-app-prod.svc.id.goog[neuraltrust/clickhouse-gcp]"

