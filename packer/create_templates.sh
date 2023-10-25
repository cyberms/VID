#!/bin/bash

################################################
# create Windows 11 and Windows 2022 Templates #
################################################


### Build all Windows Server 2022 Templates for VMware vSphere. ###
  echo "Building Windows Server 2022 Templates for VMware vSphere..."

  ### Initialize HashiCorp Packer and required plugins. ###
  echo "Initializing HashiCorp Packer and required plugins..."
  packer init ./windows/server/2022/

  ### Start the Build. ###
  echo "Starting the build...."
  packer build -force --only vsphere-iso.windows-server-standard-dexp,vsphere-iso.windows-server-standard-core -var-file=./config/vsphere.pkrvars.hcl -var-file=./config/build.pkrvars.hcl -var-file=./config/common.pkrvars.hcl ./windows/server/2022/windows-server.pkr.hcl

  ### All done. ###
  echo "Done."


