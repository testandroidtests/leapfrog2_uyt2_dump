#!/system/bin/sh
  echo 1 > /sys/module/sec/parameters/recovery_done		#tony
if ! applypatch -c EMMC:recovery:4722688:c3ef85a0dafcaaac88acff5b31a4506d5ca8fa14; then
  log -t recovery "Installing new recovery image"
  applypatch -b /system/etc/recovery-resource.dat EMMC:boot:4259840:bef01cab3da51bf9c5bba5f5243649c694c9a087 EMMC:recovery c3ef85a0dafcaaac88acff5b31a4506d5ca8fa14 4722688 bef01cab3da51bf9c5bba5f5243649c694c9a087:/system/recovery-from-boot.p
  if applypatch -c EMMC:recovery:4722688:c3ef85a0dafcaaac88acff5b31a4506d5ca8fa14; then		#tony
	echo 0 > /sys/module/sec/parameters/recovery_done		#tony
        log -t recovery "Install new recovery image completed"
  else
	echo 2 > /sys/module/sec/parameters/recovery_done		#tony
        log -t recovery "Install new recovery image not completed"
  fi
else
  echo 0 > /sys/module/sec/parameters/recovery_done              #tony
  log -t recovery "Recovery image already installed"
fi
