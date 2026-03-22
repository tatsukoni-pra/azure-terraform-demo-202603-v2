locals {
  service_name            = "tatsukoni"
  default_identity_type   = "FirstPartyIdentity"
  offer_type              = "Standard"
  kind                    = "GlobalDocumentDB"
  network_acl_bypass_ids  = []
  defaultExperience       = "Core (SQL)"
  hidden_cosmos_mmspecial = ""
  consistency_level       = "Session"
  max_interval_in_seconds = 5
  max_staleness_prefix    = 100
  failover_priority       = 0
  api_service_name        = "feat"

  # データベーススループット設定
  sql_database_max_throughput = 1000
}
