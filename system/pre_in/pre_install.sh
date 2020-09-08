#!/system/bin/sh
VERSION=2015.03.13.2
TAG=[pre_install]

log "${TAG} Version=${VERSION} running..."

persist_available () {
# vold.decrypt = "" : filesystem not encrypted
# vold.decrypt = "trigger_restart_framework" : filesystem decrypted and mounted
# vold.decrypt = * : encrypting, filesystem not mounted yet, etc
    case `getprop vold.decrypt` in
        ""|trigger_restart_framework) true;;
        *) false;;
    esac
}

has_preinstalled () {
    case `getprop persist.pre_in.$1` in
		1) true;;
		*) false;;
    esac
}

set_preinstalled () {
    setprop persist.pre_in.$1 $2
}

check_package () {
    case `pm path $1` in
		package:*) true;;
		*) false;;
    esac
}

install_apk () {
# 'local' command may have BUG..? which results in SIGSEGV.
#    local fl
#    local apk
#    local pname

    fl=$1
    apk=$2
    pname=$3

    if $fl
    then
        pm install -l -r $apk
    else
        pm install -r $apk
    fi

    # make sure successfully installed
    if check_package $pname
    then
        set_preinstalled $prop 1
        installed=true
    else
        set_preinstalled $prop 0
        log "${TAG} $pname: check_package failed"
    fi
}

check_data_app() {
    pkg=$1
    fullpath="/data/app/$pkg*"
#    log "${TAG} check_data_app: $fullpath"

    result=`ls -l $fullpath`
#    log "${TAG} result=$result"

    case $result in
		-rw-*) true;;
		*) false;;
    esac
}

pre_install () {
#    local pname
#    local apk
#    local prop
#    local ver
#    local new_ver
#    local forward_lock
# return true pre-installed
#	 false not pre-installed

    pname=$1
    apk=$2
    prop=$3
    new_ver=$4
    forward_lock=$5

    log "${TAG} package name=$pname"
#   log "${TAG} apk=$apk"
    log "${TAG} new ver=$new_ver"

    installed=false

    ver=`pm version $pname`
    log "${TAG} ver=$ver"
    case $ver in
    -1)
		if has_preinstalled $prop
		then
			if check_data_app $pname
			then
				log "${TAG} apk exists in /data/app, reinstall it"
				install_apk $forward_lock $apk $pname
				true
			else
				#log "${TAG} $pname: once installed but uninstalled by user => reinstall it for OTA anyway!"
				install_apk $forward_lock $apk $pname
				true
				#log "${TAG} $pname: once installed but uninstalled by user explicitly => Ignored in OTA!"
			fi
		else
			install_apk $forward_lock $apk $pname
			true
		fi;;
    *)
		if has_preinstalled $prop
		then
			log "${TAG} $pname: installed & marked."
		else
			log "${TAG} $pname: not marked but already installed"
			set_preinstalled $prop 1
		fi
		case $((ver < new_ver)) in
			1) 
				install_apk $forward_lock $apk $pname 
				true
				;;
			0) log "${TAG} $pname: newer version has already installed." ;;
		esac
    esac

    false
}

read_sku_id() 
# return value [ empty if failed ]
{
	current_skuid=`/system/bin/qcinvram_lite sn getsku`
	if [ $? -ne 0 ]; then # error
        current_skuid=empty
		log "${TAG} read SKU-ID error!"
	elif [ -z "${current_skuid}" ]; then # empty
        current_skuid=empty
	fi

	log "${TAG} SKU-ID = ${current_skuid}"		
}

#
# list pre-install applications.
#
# usage: pre_install package_name apk_path persist_name version_code forward_lock
#
install_apks_4_cn () {
    log "${TAG} install_apks_4_cn"

    # usage: pre_install package_name apk_path persist_name version_code forward_lock
}

install_customized_apks () {
#    pre_install com.realvnc.viewer.android.automotive /system/pre_in/VNCAutomotiveMobileViewer.apk vncAutomobileMobileViewer 96854 false	

    read_sku_id
    case $current_skuid in
    au)
        ;;
    cn)
		# China
		install_apks_4_cn
        ;;
    de)
        ;;
    jp)
        ;;
    hk)
        ;;
    kr)
        ;;
    nz)
        ;;
    tw)
        ;;
    us)
		;;
    *)
        ;;
    esac
}

copy_preinstalled_files() 
{
	result=`ls /system/etc/mobileViewer.vnclicense`
	if [ $? -eq 0 ]; then
		log "${TAG} copy files..."
		mkdir /sdcard/vnc
		mkdir /sdcard/vnc/viewerlicenses
		/system/bin/dd if=/system/etc/mobileViewer.vnclicense of=/sdcard/vnc/viewerlicenses/mobileViewer.vnclicense
		chmod 0664 /sdcard/vnc/viewerlicenses/mobileViewer.vnclicense
		#chown root sdcard_rw /sdcard/vnc/viewerlicenses/mobileViewer.vnclicense
	else
		log "${TAG} no files to copy => ignored."
	fi
}

PRE_IN_VERSION_PIVOT_PROP=ro.build.version.incremental #ro.build.fingerprint # ro.build.version.incremental

set_pre_in_version () {
	verInfo=`getprop $PRE_IN_VERSION_PIVOT_PROP`
   	setprop persist.sys.pre_in.version $verInfo
}

pre_in_version_changed () {
# enable pre_installation script after OTA
	verInfo=`getprop $PRE_IN_VERSION_PIVOT_PROP`
	pre_inVerInfo=`getprop persist.sys.pre_in.version`
	case $pre_inVerInfo in
	$verInfo)
		log "${TAG} pre_in_version matched: $verInfo"
		false;;
	*)
		log "${TAG} !!! pre_in_version changed from $pre_inVerInfo to $verInfo"
		true;;
	esac
}

###########################################
# copy files under /cache/recovery to /sdcard/Download/recovery to debug
# You must explicitly create /sdcard/Download/recovery/ folder to enable this copy on bootcomplete=1
backup_recovery_log() 
{
	DEST_FOLDER=/sdcard/Download/recovery
	RECOVERY_FOLDER=/cache/recovery/

	# if the destination folder exists
	if [ -d $DEST_FOLDER ]; then
		log "${TAG} coping ${RECOVERY_FOLDER}/* to ${DEST_FOLDER}..."
		# last_locale, last_log, last_log_r, last_install
		cp -f ${RECOVERY_FOLDER}/* ${DEST_FOLDER}
	fi
}

# set date to 2015/03/02 (not 03/01 for Los_Angelese GMT-7:00)
# and we must not set date-time after on property:dev.bootcomplete=1; otherwise, 
# the DateTime settings will be omitted by SetupWizard
setDateTime() 
{
	now=$(date)
	pos=$((${#now}-4))
	yr=${now:${pos}}
	if [ $yr -lt 2015 ]; then
		log "${TAG} date -u 1425225600 (Sun Mar 1 08:00:01 PST 2015) on ${now}"
		date -u 1425225600  # Human time (PST): Sun Mar 1 08:00:01 PST 2015
		log "${TAG} now = `date`"
	else
		log "${TAG} date is okay on reboot ${now}"
	fi
}

###########################################
# main
###########################################
if persist_available
then
	backup_recovery_log
	setDateTime

	if pre_in_version_changed
	then
		log "${TAG} pre_in_version changed; trigger copy_preinstalled_files..."
		copy_preinstalled_files

		log "${TAG} pre_in_version changed; trigger pre_installation..."
		install_customized_apks
		#pm disable com.android.settings/.Settings\$AudioProfileSettingsActivity

		# marked pre_in_version as current version
		set_pre_in_version
	else
		log "${TAG} pre_in_version matched => skip pre_in."
	fi

fi

log "${TAG} END"
exit 0
