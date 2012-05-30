#!/bin/bash

set -e

tmp_path="$VDC_ROOT/tmp"
account_id=${account_id:?"account_id needs to be set"}

cd ${VDC_ROOT}/dcmgr/

image_features_opts=
kvm -device ? 2>&1 | egrep 'name "lsi' -q || {
  image_features_opts="--virtio"
}

shlog ./bin/vdc-manage backupstorage add --uuid bkst-demo1 --base-uri="sta://sta.demo1${VDC_ROOT}/tmp/images" --storage-type=sta --description='local backup storage for sta.demo1'
shlog ./bin/vdc-manage backupstorage add --uuid bkst-demo2 --base-uri='http://localhost:8080/images/' --storage-type=webdav --description='nginx based webdav storage'

for meta in $data_path/image-*.meta; do
  (
    . $meta
    [[ -n "$localname" ]] || {
      localname=$(basename "$uri")
    }
    
    localpath=$tmp_path/images/$localname
    chksum=$(md5sum $localpath | cut -d ' ' -f1)
    size=$(ls -l "$localpath" | awk '{print $5}')
    
    shlog ./bin/vdc-manage backupobject add \
      --storage-id=bkst-demo2 \
      --uuid bo-${uuid} \
      --object-key=$localname \
      --size=$size \
      --checksum="$chksum" \
      --description='kvm 32bit'
    
    case $storetype in
      "local")
        shlog ./bin/vdc-manage image add local bo-${uuid} \
          --account-id ${account_id} \
          --uuid wmi-${uuid} \
          --arch ${arch} \
          --description "${localname} local" \
          --file_format ${fileformat} \
          --root_device ${rootdevice} \
          --service-type ${service_type} \
	  --display_name ${display_name}
        ;;
      
      "volume")
        shlog ./bin/vdc-manage image add volume bo-${uuid} \
          --account-id ${account_id} \
          --uuid wmi-${uuid} \
          --arch ${arch} \
          --description "${localname} volume" \
          --state init \
          --file_format ${fileformat} \
          --root_device ${rootdevice} \
          --service-type ${service_type} \
	  --display_name ${display_name}
        ;;
    esac

    [[ -z "$image_features_opts" ]] || {
      shlog ./bin/vdc-manage image features wmi-${uuid} ${image_features_opts}
    }
  )
done
