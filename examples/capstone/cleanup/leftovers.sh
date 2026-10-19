#!/usr/bin/env bash
# List anything in the project that could still cost money.
# Usage: ./leftovers.sh [PROJECT_ID]   (defaults to $TF_VAR_project_id)
set -uo pipefail

PROJECT="${1:-${TF_VAR_project_id:?set TF_VAR_project_id or pass a project ID}}"
found=0

check() {
  local label="$1"; shift
  local out
  if ! out="$("$@" --project="$PROJECT" --format="value(name)" 2>/dev/null)"; then
    printf '%-28s %s\n' "$label" "(couldn't list: API disabled or no access)"
    return
  fi
  if [[ -n "$out" ]]; then
    found=1
    printf '%-28s %s\n' "$label" "$(echo "$out" | tr '\n' ' ')"
  else
    printf '%-28s %s\n' "$label" "none"
  fi
}

echo "Billable leftovers in project $PROJECT:"
check "GKE clusters"            gcloud container clusters list
check "VM instances"            gcloud compute instances list
check "Persistent disks"        gcloud compute disks list
check "Static IP addresses"     gcloud compute addresses list
check "Load balancer rules"     gcloud compute forwarding-rules list
check "Cloud Routers (NAT)"     gcloud compute routers list
check "Storage buckets"         gcloud storage buckets list
check "Artifact Registry repos" gcloud artifacts repositories list --location=-
check "Secrets"                 gcloud secrets list

if [[ "$found" -eq 0 ]]; then
  echo "Nothing billable found."
else
  echo "Review the resources above; delete what you no longer need."
fi
