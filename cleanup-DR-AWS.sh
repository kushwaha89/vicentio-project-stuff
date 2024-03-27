#!/usr/bin/env bash

###################Script to do cleanup from Ekovolt cloud post AWS DR setup #############
printf "\nThis script will the instance and the image from Ekovolt Cloud acting as DR\n\n"


######## Cleanup the instance and the image ##########################
printf "\n\n\n Cleaning up the instance and the image from Ekovolt Cloud DR\n\n"
ssh eko-dc2 /bin/bash << EOF
  source admin-openrc.sh;
  sleep 1
  openstack server delete AWS-Exported-Instance1
  sleep 20
  openstack image delete AWS-Exported-Img1
EOF
printf "\n\n\n Cleanup completed successfully\n\n"
