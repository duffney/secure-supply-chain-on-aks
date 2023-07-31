output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "akv_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "akv_name" {
  value = azurerm_key_vault.kv.name
}

output "acr_name" {
  value = azurerm_container_registry.registry.name
}

output "cert_name" {
  value = azurerm_key_vault_certificate.sign-cert.name
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "wl_client_id" {
  value = azurerm_user_assigned_identity.identity.client_id
}