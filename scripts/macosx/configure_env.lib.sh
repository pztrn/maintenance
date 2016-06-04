#####################################################################
# This function checks if script was launched as standalone. This
# should not happen.
#####################################################################
function configure_env_detect_standalone()
{
	if [ -z "${PSI_DIR}" ]; then
		echo "This script should not be launched as standalone!"
		exit 1
	fi
}

#####################################################################
#
#							THE CODE
#
# Next code are meant to be called from somewhere.
#####################################################################

#####################################################################
# This function checks which OS is used on build host.
# We should not allow to run this script on any other OS beside OS X.
#####################################################################
function configure_env_check_os()
{
    # Just a checking of OS where we launched this script. We shouldn't
    # allow anyone to runit anywhere besides OS X, isn't it?
    if [ `uname` != "Darwin" ]; then
        error "This script intended to be launched only on OS X!"
        die "Do you want your data to be vanished?"
    else
    	log "Launched on Darwin OS, presuming this is OS X."
    fi

    # We are supporting x86_64 and our OS should be definetely > 10.7.
    # Check it and, if differ, exit. We do not support building on < 10.7.
    local osxver=`uname -r`
    if [ ${osxver:0:2} -lt 13 ]; then
        error "You are trying to build on unsupported version of OS X."
        die "We are supporting only OS X 10.9+ (10.9.5 preferably)!"
    else
        log "Running on OS X 10.9+"
    fi
}

#####################################################################
# This function checks for tools required to build Psi+.
# It relies on QTDIR variable, that checked (or created) in
# configure_env_detect_qt function.
#####################################################################
function configure_env_check_tools_presence()
{
    # Detecting make binary path.
    # It cannot be overrided from environment.
    MAKE=`whereis make | awk {' print $1'}`

    # Detecting qmake binary path.
    # It cannot be overrided from environment.
    QMAKE="${QTDIR}/bin/qmake"
    if [ ! -f "${QMAKE}" ]; then
        die "qmake not found! Please, install Qt from sources!"
    fi
    log "Found qmake binary: '${QMAKE}'"

    # Detecting lrelease binary path.
    # It cannot be overrided from environment.
    LRELEASE="${QTDIR}/bin/lrelease"
    if [ ! -f "${LRELEASE}" ]; then
        die "lrelease not found! Please, install Qt from sources!"
    fi
    log "Found lrelease binary: '${LRELEASE}'"

    # Detecting git binary path.
    # It can be overrided with GIT environment variable (e.g.
    # GIT=/usr/bin/git)
    if [ ! -z "${GIT}" ]; then
        log "Found git binary (from env): ${GIT}"
    else
        # We know default git path.
        GIT="/usr/bin/git"
        # Check that binary exists. Just in case :)
        if [ ! -f "${GIT}" ]; then
            die "Git binary not found! Why you deleted it?"
        fi
        log "Found git binary: '${GIT}'"
    fi

    # Detect PlistBuddy, which is used for making portable version of Psi+.
    if [ ${PORTABLE} = 1 ]; then
        if [ -x "/usr/libexec/PlistBuddy" ]; then
		    log "Found PlistBuddy"
        else
            die "PlistBuddy not found. This tool is required to make Psi+ be portable."
        fi
	fi
}

#####################################################################
# This function checks user which launched build script.
# We should not run as root, you know?
#####################################################################
function configure_env_check_user()
{
    if [ `whoami` == "root" ]; then
        die "Psi+ should not be built as root. Restart build process \
as normal user!"
    fi
}

#####################################################################
# This function created neccessary directory structure and defines
# variables for each of four subdirectories.
#####################################################################
function configure_env_create_directories()
{
    log "Creating directory structure..."

    # Root directory for build process.
    if [ ! -d "${PSI_DIR}" ]; then
        log "Creating root directory: '${PSI_DIR}'"
		mkdir -p "${PSI_DIR}" || die "Can't create work directory ${PSI_DIR}!"
	fi

    # Directory for dependencies handling.
	if [ ! -d "${PSIBUILD_DEPS_DIR}" ]; then
        log "Creating directory for dependencies: '${PSIBUILD_DEPS_DIR}'"
		mkdir -p "${PSIBUILD_DEPS_DIR}" || die "Can't create work directory ${PSIBUILD_DEPS_DIR}!"
	fi

    # Directory for build process.
    if [ -d "${PSIBUILD_BUILD_DIR}" ]; then
        log "Build directory exists, removing..."
        rm -rf "${PSIBUILD_BUILD_DIR}"
    fi
    log "Creating build directory: '${PSIBUILD_BUILD_DIR}'"
    mkdir -p "${PSIBUILD_BUILD_DIR}"

    # Directory for logs.
    if [ -d "${PSIBUILD_LOGS_DIR}" ]; then
        log "Logs directory exists, removing..."
        rm -rf "${PSIBUILD_LOGS_DIR}"
    fi
    log "Creating logs directory: '${PSIBUILD_LOGS_DIR}'"
    mkdir -p "${PSIBUILD_LOGS_DIR}"

}

#####################################################################
# This function detects currently installed version of Qt framework.
# Autodetection possible only for manually compiled Qt, which is
# installed in defailt prefix (/usr/local/Trolltech for Qt4 and
# /usr/local/Qt-{version} for Qt5)!
#####################################################################
function configure_env_detect_qt()
{

    # Some Qt4/Qt5 local vars.
    local qt4_found=0
    local qt4_path=""
    local qt4_version=""
    local qt5_found=0
    local qt5_path=""
    local qt5_version=""
    log "Checking environment..."

    # Checking Qt presence and it's version.
    # If QTDIR environment variable wasn't defined - we will try to
    # autodetect installed Qt version.
    if [ ! -z "${QTDIR}" ]; then
        # QTDIR defined - skipping autodetection.
        log "Qt path passed: ${QTDIR}"
        local qt_v=`echo ${QTDIR} | awk -F"/" {' print $(NF) '}`
        if [ ${#qt_v} -eq 0 ]; then
            local qt_v=`echo ${QTDIR} | awk -F"/" {' print $(NF-1) '}`
        fi
        configure_env_use_qt "${qt_v}" "${QTDIR}"
    else
        # Try to autodetect installed versions. We should detect one version
        # for Qt4 and one version for Qt5.
        # We are wanting self-compiled version of Qt4/5, so searching in
        # default prefix location (/usr/local/Trolltech/ for Qt4 and /usr/local/
        # for Qt5).
        log "QTDIR not defined, trying to autodetect Qt version..."
        if [ ! -d "/usr/local/Trolltech" ]; then
            qt4_found=0
        else
            qt4_found=1
        fi

        local possible_qt5=`ls -1 /usr/local | grep "Qt-5*"`
        if [ ${#possible_qt5} -ne 0 ]; then
            qt5_found=1
        else
            qt5_found=0
        fi

        # Detect Qt4 path and version.
        if [ ${qt4_found} -eq 1 ]; then
            # Detecting installed Qt4 version.
            # We are relying on assumption that Qt4 is installed in
            # /usr/local/Trolltech. If you're installed Qt4 in other prefix
            # you should specify QTDIR manually.
            qt4_version=`ls /usr/local/Trolltech | grep Qt | awk '{print $NF}' | cut -d "-" -f 2`
            if [ "${#qt4_version}" -eq 0 ]; then
                log "Could not detect installed Qt4 version."
            else
                log "Detected Qt4 version: ${qt4_version}"
            fi
        fi

        # Detect Qt5 path and version
        if [ ${qt5_found} -eq 1 ]; then
            # Detecting installed Qt5 version.
            # We are relying on assumption that Qt5 is installed in
            # /usr/local/. If you're installed Qt5 in other prefix
            # you should specify QTDIR manually.
            qt5_version=`echo ${possible_qt5} | grep Qt | awk '{print $NF}' | cut -d "-" -f 2`
            if [ "${#qt5_version}" -eq 0 ]; then
                log "Could not detect installed Qt5 version."
            else
                log "Detected Qt5 version: ${qt5_version}"
            fi
        fi

        # If we found both Qt4 and Qt5, and "--prefer-qt5" wasn't passed - ask
        # user which Qt version should we use.
        if [ ${qt4_found} -eq 1 -a ${qt5_found} -eq 1 -a ${PREFER_QT5} -eq 0 ]; then
            echo -n -e " \033[1;43m!\033[0m Detected both Qt4 and Qt5. Please, enter \"1\" to use Qt4, and \"2\" to use Qt5. "
            read -n 1 qt_to_use
            echo
            if [ "${qt_to_use}" == "1" ]; then
                log "Will use Qt4."
                configure_env_use_qt "${qt4_version}" "/usr/local/Trolltech/Qt-${qt4_version}"
            elif [ "${qt_to_use}" == "2" ]; then
                log "Will use Qt5."
                configure_env_use_qt "${qt5_version}" "/usr/local/Qt-${qt5_version}"
            fi
        elif [ ${qt4_found} -eq 1 -a ${qt5_found} -eq 1 -a ${PREFER_QT5} -eq 1 ]; then
            log "Found both Qt4 and Qt5, but \"--prefer-qt5\" parameter was passed. Forcing Qt5."
            configure_env_use_qt "${qt5_version}" "/usr/local/Qt-${qt5_version}"
        else
            if [ ${qt4_found} -eq 1 -a ${qt5_found} -eq 0 ]; then
                log "Will use Qt4."
                configure_env_use_qt "${qt4_version}" "/usr/local/Trolltech/Qt-${qt4_version}"
            elif [ ${qt4_found} -eq 0 -a ${qt5_found} -eq 1 ]; then
                log "Will use Qt5."
                configure_env_use_qt "${qt5_version}" "/usr/local/Qt-${qt5_version}"
            fi
        fi
    fi
}

#####################################################################
# This function prepares build flags for building process.
# These build flags will be used for building all parts of Psi+,
# including dependencies.
#####################################################################
function configure_env_prepare_buildflags()
{
	log "Preparing build flags..."

    # Check CFLAGS for march/mtune parameters.
    if [ "${CFLAGS/march\=x86-64}" == "${CFLAGS}" ]; then
        log "Adding -march=x86-64 to CFLAGS"
        export CFLAGS="${CFLAGS} -march=x86-64"
    fi

    if [ "${CFLAGS/mtune\=generic}" == "${CFLAGS}" ]; then
        log "Adding -mtune=generic to CFLAGS"
        export CFLAGS="${CFLAGS} -mtune=generic"
    fi

    # Checking CPPFLAGS for same parameters.
    if [ "${CPPFLAGS/march\=x86-64}" == "${CPPFLAGS}" ]; then
        log "Adding -march=x86-64 to CPPFLAGS"
        export CPPFLAGS="${CPPFLAGS} -march=x86-64"
    fi

    if [ "${CPPFLAGS/mtune\=generic}" == "${CPPFLAGS}" ]; then
        log "Adding -mtune=generic to CPPFLAGS"
        export CPPFLAGS="${CPPFLAGS} -mtune=generic"
    fi

    log "Forcing QMAKE_CXXFLAGS/QMAKE_CXXFLAGS_RELEASE values to '-march=x86-64 -mtune=generic'..."
    export QMAKE_CXXFLAGS="-march=x86-64 -mtune=generic"
    export QMAKE_CXXFLAGS_RELEASE="-march=x86-64 -mtune=generic"

    log "Forcing CMAKE_C_FLAGS/CMAKE_CXX_FLAGS values to '-march=x86-64 -mtune=generic'..."
    export CMAKE_C_FLAGS="${CMAKE_C_FLAGS} -march=x86-64 -mtune=generic"
    export CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -march=x86-64 -mtune=generic"
}

#####################################################################
# This function prepares some directory variables, like
# PSI_DEPS_DIR, PSI_SOURCES_DIR, etc.
#####################################################################
function configure_env_prepare_dir_variables()
{
	log "Configuring PSIBUILD_* variables..."
	# We already know where PSI_DIR is. So using this as root
	# directory for all other directories.
	# Directory where Psi and Psi+ sources are placed.
	export PSIBUILD_SOURCES_DIR="${PSI_DIR}/sources"
	# Directory for dependencies.
	export PSIBUILD_DEPS_DIR="${PSI_DIR}/dependencies"
	# Directory for building.
	export PSIBUILD_BUILD_DIR="${PSI_DIR}/build"
	# Direcotry for logs
	export PSIBUILD_LOGS_DIR="${PSI_DIR}/logs"
}

#####################################################################
# This function will tune DYLD_LIBRARY_PATH variable.
#####################################################################
function configure_env_tune_dyld_path()
{
    log "Tuning DYLD_LIBRARY_PATH to point to our dep_root..."
    export DYLD_LIBRARY_PATH="${PSIBUILD_DEPS_DIR}/dep_root/lib/:${DYLD_LIBRARY_PATH}"
}

#####################################################################
# This function will tune PATH variable.
#####################################################################
configure_env_tune_path()
{
    log "Adding '${PSIBUILD_DEPS_DIR}/dep_root/bin' to PATH..."
    export PATH="${PSIBUILD_DEPS_DIR}/dep_root/bin:${PATH}"
}

#####################################################################
# This function will tune pkg-config paths.
#####################################################################
function configure_env_tune_pkgconfig()
{
    log "Forcing pkg-config to take a look into our dependencies root's pkg-config directory..."
    # We have nothing more on clean system. And we need no more for clean build.
    export PKG_CONFIG_PATH="${PSIBUILD_DEPS_DIR}/dep_root/lib/pkgconfig:/usr/lib/pkgconfig/:${PKG_CONFIG_PATH}"
    log "PKG_CONFIG_PATH is now: ${PKG_CONFIG_PATH}"
}

#####################################################################
# This function exports Qt version.
#####################################################################
function configure_env_use_qt()
{
    local version=$1
    local path=$2
    local path=`echo ${path} | sed -e "s/\/\//\//"`
    export QTDIR="${path}"
    export QT_VERSION="${version}"
    export QT_VERSION_MAJOR="${version:0:1}"
    if [ $QT_VERSION_MAJOR -eq 4 ]; then
        PKG_CONFIG_PATH="/usr/local/Qt4.8/lib/pkgconfig"
    fi
    log "Will use Qt-${QT_VERSION} located at '${QTDIR}'"
}

#####################################################################
# This function prepares environment for building Psi+ and
# dependencies.
#####################################################################
function configure_env_prepare_environment()
{
	log "Preparing environment..."
	configure_env_check_user
	configure_env_check_os
	configure_env_detect_qt
	configure_env_check_tools_presence
	configure_env_prepare_dir_variables
	configure_env_create_directories
	configure_env_prepare_buildflags
    configure_env_tune_path
    configure_env_tune_pkgconfig
    configure_env_tune_dyld_path
}

configure_env_detect_standalone