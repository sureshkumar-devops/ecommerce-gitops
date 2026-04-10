path "secret/data/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "secret/metadata/*" {
  capabilities = ["read", "list"]
}


