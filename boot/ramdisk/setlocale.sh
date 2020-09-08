#!/system/bin/sh
VERSION=2015.01.12.2
TAG=[setlocale]

log "${TAG} Version=${VERSION} running..."

current_skuid=unknown

persist_available () {
# vold.decrypt = "" : filesystem not encrypted
# vold.decrypt = "trigger_restart_framework" : filesystem decrypted and mounted
# vold.decrypt = * : encrypting, filesystem not mounted yet, etc
    case `getprop vold.decrypt` in
        ""|trigger_restart_framework) true;;
        *) false;;
    esac
}

# 10-byte=20 Hex values
# YMDD[19,18,17,16]: Y: 201(5-9); M=[1=Jan,...,C=Dec]; DD=[01, ...,0x1F=31]
# Product ID[15,14,13,12,11,10]: fixed value;
# PV[9,8]=Product Variant=0x64(100) for prototypes
# CM ID[7,6]=Manufacturer Code=fixed value
# Mfg Cycle[5,4]: 0x00(before EP), 0x01=EP, 0x02=FEP; others:MP
# Seq [3,2,1,0] 

set_device_id_prop() 
{
	device_id=`/system/bin/qcinvram_lite sn getdev`
	if [ $? -ne 0 ]; then # ERROR
        device_id=empty
		log "${TAG} Device-ID=(empty) due to /system/bin/qcinvram_lite sn getdev ERROR."
	elif [ -z "${device_id}" ]; then # empty
        device_id=empty
		log "${TAG} Device-ID=(empty)."
	elif [ "${device_id}" = "0123456789ABCDEF" ]; then	# skipping setprop if it is not a valid value
		log "${TAG} Device-ID=${device_id} (default)!"
	else
		setprop persist.sys.deviceID "${device_id}"
	    log "${TAG} persist.sys.deviceID=${device_id}"
	fi
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

set_locale_timezone() 
# $1 language, such as en, zh, ja
# $2 country, such as US, TW, JP, or CN
# $3 time-zone string, such as Australia/Sydney, Europe/Amsterdam, or Asia/Taipei
# $4 enable/disable locale-timezone settings [ 0 (disable) | 1 (enable)] 
{
	if [ $4 -eq 1 ]; then
		log "${TAG} pre_set_locale_timezone ${1}_${2} $3"
		# set default language
		if [ -n $1 ] && [ -n $2 ]; then # bot lang and country are not empty
			setprop persist.sys.language $1
			setprop persist.sys.country $2
		fi

		if [ -n $3 ]; then # not empty, then set timezone
			setprop persist.sys.timezone $3
		fi
	fi
}

SKUID_PROP=persist.sys.sku

set_skuid_prop () {
# $1 value
	if [ "${1}" = "0123456789ABCDEF" ] || [ "${1}" = "empty" ]; then	# skipping setprop if it is not a valid value
		log "${TAG} SKU-ID=${1} (default)!"
	else
		setprop ${SKUID_PROP} ${1}  # execute it only once.
		log "${TAG} ${SKUID_PROP}=${1}"
	fi
}

get_skuid_prop () {
	skuidPropValue=`getprop ${SKUID_PROP}`
}

syncLastLocale()
# set locale based on the current locale settings in decrypted mode
{
	LAST_LOCALE_FILE=/cache/last_locale
	if [ -f $LAST_LOCALE_FILE ]; then
	    locale=`cat $LAST_LOCALE_FILE`
		log "${TAG} last_locale=${locale}"
		if [ ${#locale} -eq 5 ] && [ "${locale:2:1}" = "_" ]; then	# set default language in encrypted mode
			lang=${locale:0:2}
			country=${locale:3:2}
			set_locale_timezone $lang $country "" 1
		else
			log "${TAG} invalid ${LAST_LOCALE_FILE} value: ${locale}."
		fi
	else
		log "${TAG} ${LAST_LOCALE_FILE} is missing!"
		#set_locale_timezone en US "" 1 # falls back to en_US
	fi
}

pre_set_locale_timezone() 
# $1 enable/disable locale-timezone settings [ 0 (disable to set SKU-ID only) | 1 (enable)] 
{
    read_sku_id
    case $current_skuid in
    at)
		# Austria
		set_locale_timezone de DE Europe/Amsterdam $1 
        ;;
    au)
		# there is no en_AU in lauguages_full.mk
		set_locale_timezone en GB Australia/Sydney $1 
        ;;
    ca)
		# Canada
		set_locale_timezone en US America/Los_Angeles $1 
        ;;
    cn)
		set_locale_timezone zh CN Asia/Shanghai $1 
        ;;
    de)
		# Germany
		set_locale_timezone de DE Europe/Amsterdam $1 
        ;;
    es)
		# Spain
		set_locale_timezone es ES Europe/Brussels $1 
        ;;
    eu)
		# Europe
		#set_locale_timezone en GB Europe/Amsterdam $1
		log "${TAG} SKU-ID: eu => leave locale_timezone intact!"
        ;;
    jp)
		set_locale_timezone ja JP Asia/Tokyo $1 
        ;;
    hk)
		set_locale_timezone zh TW Asia/Hong_Kong $1 
        ;;
    kr)
		set_locale_timezone ko KR Asia/Seoul $1 
        ;;
    mx)
		# Mexco
		set_locale_timezone es ES America/Mexico_City $1 
        ;;
    nz)
		# there is no en_NZ in lauguages_full.mk
		set_locale_timezone en GB Pacific/Auckland $1 
        ;;
    ru)
		# Russia
		set_locale_timezone ru RU Europe/Moscow $1 
        ;;
    tw)
		set_locale_timezone zh TW Asia/Taipei $1 
        ;;
    ua)
		# Ukraine
		set_locale_timezone uk UA Europe/Athens $1 
        ;;
    us)
		# United States
		set_locale_timezone en US America/Los_Angeles $1 
        ;;
    uk)
		# united kingdom
		set_locale_timezone en GB Europe/London $1 
		;;
    *)
		log "${TAG} unknown SKU-ID: $current_skuid => leave locale_timezone intact!"
		#set_locale_timezone en US America/Los_Angeles
		# reset current_skuid so as to set in property for OBA checkup
		#current_skuid="unknown(${current_skuid})"  
        ;;
    esac

	# set prop for mfg checkup
	set_skuid_prop ${current_skuid}
}

set_blocked_apk_prop () {
# $1 value
    setprop persist.sys.blocked.prein_apks $1 
	log "${TAG} persist.sys.blocked.prein_apks=${1}"
}

set_blocked_preinstall_Apks () {

	get_skuid_prop	
    case $current_skuid in
    us)
		set_blocked_apk_prop prein_block_none.xml
		;;
    *)
		set_blocked_apk_prop prein_block_none.xml
        ;;
    esac
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

########## main ###########


if persist_available
then
	presetLocale=`getprop persist.sys.locale.pre_set`
	if [ "${presetLocale}" = "1" ]; then
	    log "${TAG} pre-set-locale => reset Device-ID and SKU-ID only."
	    pre_set_locale_timezone 0 # always reset SKU-ID in case it changes on reboot
	    set_device_id_prop # always reset SKU-ID in case it changes on reboot
	else
	    pre_set_locale_timezone 0
	    set_device_id_prop

	    setprop persist.sys.locale.pre_set 1  # execute it only once and set it as the last step
	fi

	if pre_in_version_changed
	then
		set_blocked_preinstall_Apks
		# do NOT marked pre_in_version as current version, because pre_install.sh depends on it
		#set_pre_in_version
	fi
else # encrypted, sync locale from the cache
	syncLastLocale
fi

chown system:nvram /data/nvram
chown system:nvram /data/nvram/APCFG
chown system:nvram /data/nvram/APCFG/APRDCL
chown system:nvram /data/nvram/APCFG/APRDCL/AUXADC
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_ver1_Vol_custom
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_AudEnh_Control_Opt
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_Buffer_DC_Calibration_Param
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_CompFlt
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_Sph
chown system:nvram /data/nvram/APCFG/APRDCL/Audio_Wb_Sph
chown system:nvram /data/nvram/APCFG/APRDCL/FILE_VER
chown system:nvram /data/nvram/APCFG/APRDCL/HWMON_ACC
chown system:nvram /data/nvram/APCFG/APRDCL/Headphone_CompFlt
chown system:nvram /data/nvram/APCFG/APRDCL/VibSpk_CompFlt
chown system:nvram /data/nvram/APCFG/APRDEB
chown system:nvram /data/nvram/APCFG/APRDEB/BT_Addr
chown system:nvram /data/nvram/APCFG/APRDEB/OMADM_USB
chown system:nvram /data/nvram/APCFG/APRDEB/SN
chown system:nvram /data/nvram/APCFG/APRDEB/Sensor_Data
chown system:nvram /data/nvram/APCFG/APRDEB/WIFI
chown system:nvram /data/nvram/APCFG/APRDEB/WIFI_CUSTOM


log "${TAG} END"
exit 0
