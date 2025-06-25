#!/bin/bash
cd backup

timestamp=$(date +"%Y%m%d%H%M")

controller="ziti-controller"
router="ziti-router"

source_dir1="/var/lib/private/ziti-controller"
source_dir2="/var/lib/private/ziti-router"

tar_file1="${controller}_${timestamp}.tar.gz"
tar_file2="${router}_${timestamp}.tar.gz"

  
sudo tar -czvf "$tar_file1" "$source_dir1"
echo "✓ Commander 資料備份成功"
echo "$timestamp	$source_dir1	$tar_file1" >> backup.log
sudo tar -czvf "$tar_file1" "$source_dir1"
echo "$timestamp	$source_dir2	$tar_file2" >> backup.log
sudo tar -czvf "$tar_file2" "$source_dir2"
echo "✓  Router 資料備份成功"

cd ..
