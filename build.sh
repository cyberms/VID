#################################
# Ansible for vCenterdeployment #
#################################
cd ansible
ansible-playbook -i inventory.yml deploy-vcenter.yml
cd ..

#Packer

# create windows 11 template

echo "Starting the build Windows 11 Template"
cd packer
packer init ./windows/desktop/11/
packer build -force -var-file ./config/vsphere.pkrvars.hcl -var-file ./config/build.pkrvars.hcl -var-file ./config/common.pkrvars.hcl ./windows/desktop/11/
cd ..

# create windows 2022 template
# to change the Windows Server 2022 version, set the --only Command
# standard dexp: --only vsphere-iso.windows-server-standard-dexp
# standard core: --only vsphere-iso.windows-server-standard-core
# datacenter dexp: --only vsphere-iso.windows-server-datacenter-dexp
# datacenter core: --only vsphere-iso.windows-server-datacenter-core
      
 echo "Starting the build Windows 2022 Template"
 cd packer
 packer init ./windows/server/2022/
 packer build -force --only vsphere-iso.windows-server-standard-dexp -var-file ./config/vsphere.pkrvars.hcl -var-file ./config/build.pkrvars.hcl -var-file ./config/common.pkrvars.hcl ./windows/server/2022/
 cd ..

# Terraform

# cd terraform
# terraform init
# terraform plan -target=module.pdc
# terraform apply --auto-approve -target=module.pdc
# cd ..

# Ansible
# als erste den PDC erstellen und konfigurieren lassen

# Terraform die zweite, alles nachdem der PDC vorhanden ist, damit die VM's direkt in die Dom aufgenommen werden können


#Ansible die zweite, alle weiteren VM's konfiguriere