locals {
  service_name = "tatsukoni"

  # 環境ごとのアドレス空間
  address_space = var.env == "dev" ? ["10.0.0.0/16"] : ["10.1.0.0/16"]
}
