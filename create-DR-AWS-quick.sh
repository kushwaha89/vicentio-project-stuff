#!/usr/bin/env bash

###################Script to createsnap of a volume and copy the volume to an instance #############
tstinstance_id="i-0271bdb8269410f51" #This wasfor rahtest2
#tstinstance_id="i-0d1fe218016c46d76"  #This is for rahtest3
tstinstvol_id="vol-026ab11e2a9769581" #This is for rahtest2
#tstinstvol_id="vol-079f4f6ca4f50b53d" #This is for rahtest3
migratorinst_id="i-0d26146a56efa86b8"
printf "\nThis script will create snapshot of the test instance on AWS and copy the instance as an image to Ekovolt Cloud acting as DR\n\n"

##########Create snapshot ###########
snap_outpt=$(aws ec2 create-snapshot --description snap-rahtest2-1 --volume-id ${tstinstvol_id})
snap_id=$(echo "${snap_outpt}" | grep -oP '(?<="SnapshotId": ")[^"]*')
printf "\nSnapshot created successfully with id: \t${snap_id}"
printf "\nProceeding to create volume with this snapshot, waiting for snapshot creation to complete"
sleep 120

########## Create volume from the new snapshot ########
volcreate_outpt=$(aws ec2 create-volume --availability-zone us-east-1d --iops 500 --volume-type gp3 --snapshot-id ${snap_id})
volc_id=$(echo "${volcreate_outpt}" | grep -oP '(?<="VolumeId": ")[^"]*')
printf "\nVolume created successfully with id: \t${volc_id}"
printf "\n\n\nProceeding to dump this volume in RAW format locally"
sleep 5

########## Dump the volume as a raw image locally #################
########## Attach this new volume to volumemigrator instance ######
attchvol_outpt=$(aws ec2 attach-volume --device /dev/xvdd --instance-id ${migratorinst_id} --volume-id ${volc_id})
sleep 10
printf "\nVolume attached"

######### Copy the contents of the volume in RAW format ###########
printf "\nConversion to RAW started"
sudo dd if=/dev/xvdd conv=sync,noerror bs=64k status=progress | gzip -c > /root/aws-image.raw.gz
sleep 2

######### Check if the file exists now ############
if (ls -l /root | grep aws-image.raw.gz) ; then
    printf "\nConversion to RAW format was successful"
    printf "\n\n\nProceeding to remove stale volumes and snapshots . . ."
    aws ec2 detach-volume --device /dev/xvdd --instance-id ${migratorinst_id} --volume-id ${volc_id}
    sleep 30
    aws ec2 delete-volume --volume-id ${volc_id}
    sleep 10
    aws ec2 delete-snapshot --snapshot-id ${snap_id}
else
    printf "\nConversion Failed !!!!"
fi

######### Copy over the image to Ekovolt cloud acting as DR #######
printf "\n\n\nCreating instance as an image at Ekovolt Cloud acting as DR"
printf "\nCopying the image . . ."
scp /root/aws-image.raw.gz eko-dc2:/home/ekoosp/
rm -rf aws-image.raw.gz

printf "\nDeflating and Uploading the instance as an image . . ."
ssh eko-dc2 /bin/bash << EOF
  source admin-openrc.sh;
  sleep 1
  gzip -d aws-image.raw.gz
  sleep 2 
  openstack image create --disk-format raw --container-format bare --public --file ./aws-image.raw --progress AWS-Exported-Img1
  sleep 1
  rm -rf aws-image.raw.gz aws-image.raw
EOF
printf "\nImage uploaded successfully"

######## Create instance from this new image ##########################
printf "\n\n\n Creating DR Instance from this image"
ssh eko-dc2 /bin/bash << EOF
  source admin-openrc.sh;
  sleep 1
  openstack server create --flavor m1.medium --image AWS-Exported-Img1 --key-name op-key2 --nic net-id=74dfa0d3-554a-4fe6-92c5-452566845b90 --security-group 8cf4c942-9d0e-45ab-a3f7-ab615e5c7310 AWS-Exported-Instance1
  sleep 20
  openstack server add floating ip AWS-Exported-Instance1 169.239.18.122
  sleep 15
EOF

####### Get the instance details which we just created ###############
sleep 1
ekoinst_det=$(ssh eko-dc2 /home/ekoosp/get-aws-inst.sh)
printf "\n\n\nInstance created at Ekovolt Cloud acting as DR is as follows \n\n"
printf "${ekoinst_det}\n\n"
