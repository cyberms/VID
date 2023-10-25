# root main.tf

# install primary domain controller
module "pdc" {
  source = "./modules/pdc"
}

# install jumphost
module "studentpc" {
  source = "./modules/studentpc"
}

# install Server OS VDA
module "svda" {
  source = "./modules/svda"
}

# install fileserver
module "fileserver" {
  source = "./modules/fileserver"
}

# install sql server
module "sqlserver" {
  source = "./modules/sqlserver"
}

# install first storefront server
module "stf001" {
  source = "./modules/stf001"
}

# install second storefront server
module "stf002" {
  source = "./modules/stf002"
}

# install first delivery controller server
module "ddc001" {
  source = "./modules/ddc001"
}

# install second delivery controller server
module "ddc002" {
  source = "./modules/ddc002"
}

# install worker
module "worker" {
  source = "./modules/worker"
}