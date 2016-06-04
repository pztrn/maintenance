# pkg-config
DEP_PKGCONFIG_SOURCE_URL="https://pkg-config.freedesktop.org/releases/"
DEP_PKGCONFIG_VERSION="0.29.1"
DEP_PKGCONFIG_FILENAME="pkg-config-${DEP_PKGCONFIG_VERSION}.tar.gz"
# autoconf
DEP_AUTOCONF_SOURCE_URL="http://ftp.gnu.org/gnu/autoconf/"
DEP_AUTOCONF_VERSION="2.69"
DEP_AUTOCONF_FILENAME="autoconf-${DEP_AUTOCONF_VERSION}.tar.gz"
# automake
DEP_AUTOMAKE_SOURCE_URL="http://ftp.gnu.org/gnu/automake/"
DEP_AUTOMAKE_VERSION="1.15"
DEP_AUTOMAKE_FILENAME="automake-${DEP_AUTOMAKE_VERSION}.tar.gz"
# libtool
DEP_LIBTOOL_SOURCE_URL="http://mirror.tochlab.net/pub/gnu/libtool/"
DEP_LIBTOOL_VERSION="2.4.6"
DEP_LIBTOOL_FILENAME="libtool-${DEP_LIBTOOL_VERSION}.tar.gz"
# minizip
DEP_MINIZIP_SOURCE_URL="http://zlib.net/"
DEP_MINIZIP_VERSION="1.2.8"
DEP_MINIZIP_FILENAME="zlib-${DEP_MINIZIP_VERSION}.tar.gz"
# libidn
DEP_LIBIDN_SOURCE_URL="http://ftpmirror.gnu.org/libidn/"
DEP_LIBIDN_VERSION="1.32"
DEP_LIBIDN_FILENAME="libidn-${DEP_LIBIDN_VERSION}.tar.gz"
# Qt Cryptographic Architecture
DEP_QCA_SOURCE_URL="http://delta.affinix.com/download/qca/2.0/"
DEP_QCA_VERSION="2.1.0"
DEP_QCA_FILENAME="qca-${DEP_QCA_VERSION}.tar.gz"
# GStreamer
DEP_GST_SOURCE_URL="http://psi-im.org/files/deps/"
DEP_GST_VERSION="0.10.36"
DEP_GST_FILENAME="gstbundle-${DEP_GST_VERSION}-mac.tar.bz2"
# Growl
DEP_GROWL_SOURCE_URL="http://growl.cachefly.net/"
DEP_GROWL_VERSION="1.3.1"
DEP_GROWL_FILENAME="Growl-${DEP_GROWL_VERSION}-SDK.zip"
# Psimedia
DEP_PSIMEDIA_SOURCE_URL="https://github.com/psi-plus/psimedia.git"

#####################################################################
# Main function for this file. It'll be called by psibuild.
#####################################################################
function build_deps_build()
{
	log "Building dependencies. This could take awhile..."
    build_deps_default_way "autoconf" "autoconf" "bin" "autoconf-${DEP_AUTOCONF_VERSION}" ""
    build_deps_default_way "automake" "automake" "bin" "automake-${DEP_AUTOMAKE_VERSION}" ""
    build_deps_default_way "pkgconfig" "pkg-config" "bin" "pkg-config-${DEP_PKGCONFIG_VERSION}" "--with-internal-glib"
    build_deps_default_way "libtool" "libtoolize" "bin" "libtool-${DEP_LIBTOOL_VERSION}" "--disable-dependency-tracking --enable-ltdl-install"
	build_deps_qconf
	build_deps_minizip
    build_deps_default_way "libidn" "libidn.dylib" "library" "libidn-${DEP_LIBIDN_VERSION}" "--disable-dependency-tracking --disable-csharp"
    build_deps_qca
    build_deps_gstreamer
    build_deps_psimedia
    build_deps_growl
}

#####################################################################
# This function checks if script was launched as standalone. This
# should not happen.
#####################################################################
function build_deps_detect_standalone()
{
	if [ -z "${PSIBUILD_DEPS_DIR}" ]; then
		echo "This script should not be launched as standalone!"
		exit 1
	fi
}

#####################################################################
# Default way to build dependencies, e.g. ./configure && make && make install.
# All non-default things should be hardcoded.
#
# Params accepted:
#   $1 - dependency name
#   $2 - binary to search. Used for detecting if dependency was properly
#        installed.
#   $3 - dependency type. Supports "bin" and "library" for now.
#   $4 - directory name from tarball.
#   $5 - additional configure options to pass.
#
# Note to man who can probably patch this function: do not add
# anything AFTER $additional_configure_opts! Add before!
# And don't forget about one more shift AND fixing build_deps_build()
# calls!
#####################################################################
function build_deps_default_way()
{
    local dep=$1
    local binary_to_search=$2
    local detection_type=$3
    local source_dir_name=$4
    shift
    shift
    shift
    shift
    local additional_configure_opts=$@
    log "Detecting ${dep}..."

    if [ "${detection_type}" == "bin" ]; then
        local bin_path="${PSIBUILD_DEPS_DIR}/dep_root/bin/${binary_to_search}"
    elif [ "${detection_type}" == "library" ]; then
        local bin_path="${PSIBUILD_DEPS_DIR}/dep_root/lib/${binary_to_search}"
    else
        die "Unsupported detection type: ${detection_type}"
    fi

    if [ ! -f "${bin_path}" ]; then
        log "Downloading ${dep} sources..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/${dep}"
        cd "${PSIBUILD_DEPS_DIR}/${dep}"

        # For downloading things from web we should obtain path to sources.
        local bts_uppercase=`echo ${dep} | awk {' print toupper($0) '}`
        local source_url="DEP_${bts_uppercase}_SOURCE_URL"
        local source_filename="DEP_${bts_uppercase}_FILENAME"
        local source_version="DEP_${bts_uppercase}_VERSION"
        URL="${!source_url}/${!source_filename}"
        log "URL: ${URL}"
        curl -L "${URL}" -o "${!source_filename}"

        # Extracting sources...
        tar -xf "${!source_filename}"
        cd "${source_dir_name}"

        # Configuring sources...
        log "Configuring ${dep}..."
        log "Passed additional configuration options: ${additional_configure_opts}"
        ./configure --prefix="${PSIBUILD_DEPS_DIR}/dep_root" ${additional_configure_opts} >> "${PSIBUILD_LOGS_DIR}/${dep}-configure.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "${dep} configuration" "${PSI_DIR}/logs/${dep}-configure.log"
        fi

        # Compilation.
        log "Compiling ${dep}..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/${dep}-make.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "${dep} compilation" "${PSI_DIR}/logs/${dep}-make.log"
        fi

        # Installation.
        log "Installing ${dep}..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/${dep}-install.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "${dep} installation" "${PSI_DIR}/logs/${dep}-install.log"
        fi
    fi
}

#####################################################################
# GStreamer installation/detection
#####################################################################
function build_deps_gstreamer()
{
    log "Detecting GStreamer..."
    if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/libgstbase-0.10.0.dylib" ]; then
        log "Downloading GStreamer source..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/gstreamer"
        cd "${PSIBUILD_DEPS_DIR}/gstreamer"
        curl -L "${DEP_GST_SOURCE_URL}/${DEP_GST_FILENAME}" -o "${DEP_GST_FILENAME}"
        tar -xf "${DEP_GST_FILENAME}"
        cd "gstbundle-${DEP_GST_VERSION}-mac"
        log "Copying GStreamer to dep_root..."
        cp -R x86_64/* "${PSIBUILD_DEPS_DIR}/dep_root"
    fi

    log "Detected GStreamer library:"
    export GST_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
    export GST_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libgstbase-0.10.0.dylib"
    log "Include path: '${GST_INCLUDE}'"
    log "Library path: '${GST_LIBRARY}'"
}

#####################################################################
# Growl installation/detection
#####################################################################
function build_deps_growl()
{
    log "Detecting Growl..."
    if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/Growl.framework/Versions/A/Growl" ]; then
        log "Downloading Growl source..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/growl"
        cd "${PSIBUILD_DEPS_DIR}/growl"
        curl -L "${DEP_GROWL_SOURCE_URL}/${DEP_GROWL_FILENAME}" -o "${DEP_GROWL_FILENAME}"
        tar -xf "${DEP_GROWL_FILENAME}"
        cd "Growl-${DEP_GROWL_VERSION}-SDK"
        log "Copying framework into '${PSIBUILD_DEPS_DIR}/dep_root/lib'..."
        cp -R Framework/Growl.framework "${PSIBUILD_DEPS_DIR}/dep_root/lib"
    fi

    log "Detected Growl library:"
    export GROWL_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/lib/Growl.framework/Versions/A/Headers"
    export GROWL_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/Growl.framework/Versions/A/Growl"
    log "Include path: '${GROWL_INCLUDE}'"
    log "Library path: '${GROWL_LIBRARY}'"
}

#####################################################################
# Minizip (zlib) installation/detection.
#####################################################################
function build_deps_minizip()
{
	log "Detecting minizip library..."
	if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/libminizip.dylib" ]; then
		log "Downloading minizip (zlib) sources..."
		mkdir -p "${PSIBUILD_DEPS_DIR}/zlib"
		cd "${PSIBUILD_DEPS_DIR}/zlib"
		curl -L "${DEP_MINIZIP_SOURCE_URL}/${DEP_MINIZIP_FILENAME}" -o "${DEP_MINIZIP_FILENAME}"
		tar -xf "${DEP_MINIZIP_FILENAME}"
        cd "zlib-${DEP_MINIZIP_VERSION}"
        log "Configuring ZLib..."
        ./configure --prefix="${PSIBUILD_DEPS_DIR}/dep_root" >> "${PSIBUILD_LOGS_DIR}/zlib-configure.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "zlib configuration" "${PSI_DIR}/logs/zlib-configure.log"
        fi
        log "Compiling ZLib..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/zlib-make.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "zlib compilation" "${PSI_DIR}/logs/zlib-make.log"
        fi
        cd contrib/minizip
        # Sed magic from https://github.com/Homebrew/homebrew-core/blob/master/Formula/minizip.rb
        log "Executing sed magic..."
        sed -i "" "s/\-L\$\(zlib_top_builddir\)/\$\(zlib_top_builddir\)\/libz.a/" Makefile.am
        sed -i "" "s/\-version\-info\ 1\:0\:0\ \-lz/\-version\-info\ 1\:0\:0/" Makefile.am
        sed -i "" "s/libminizip.la\ \-lz/libminizip.la/" Makefile.am
        log "Configuring minizip..."
        autoreconf -fi  >> "${PSIBUILD_LOGS_DIR}/minizip-configure.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "minizip configuration" "${PSI_DIR}/logs/minizip-configure.log"
        fi
        ./configure --prefix="${PSIBUILD_DEPS_DIR}/dep_root" >> "${PSIBUILD_LOGS_DIR}/minizip-configure.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "minizip configuration" "${PSI_DIR}/logs/minizip-configure.log"
        fi
        log "Compiling minizip..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/minizip-make.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "minizip compilation" "${PSI_DIR}/logs/minizip-make.log"
        fi
        log "Installing minizip..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/minizip-install.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "minizip installation" "${PSI_DIR}/logs/minizip-install.log"
        fi
	fi

    log "Found minizip library:"
    export MINIZIP_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
    export MINIZIP_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libminizip.dylib"
    log "Include path: '${MINIZIP_INCLUDE}'"
    log "Library path: '${MINIZIP_LIBRARY}'"
}

#####################################################################
# psimedia installation/detection
#####################################################################
function build_deps_psimedia()
{
    log "Detecting psimedia..."
    if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/libpsimedia.dylib" ]; then
        log "Downloading Psimedia sources..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/psimedia"
        cd "${PSIBUILD_DEPS_DIR}/psimedia"
        git clone "${DEP_PSIMEDIA_SOURCE_URL}" .
        log "Configuring Psimedia..."
        #QTDIR="${QTDIR}" ${QCONF} >> "${PSIBUILD_LOGS_DIR}/psimedia-qconf.log" 2>&1
        #PKG_CONFIG_PATH=~/psi/dependencies/dep_root/lib/pkgconfig ./configure --qtdir="${QTDIR}"
        log "Building Psimedia..."
        #${MAKE} ${MAKEOPTS}
    else
        log "Found Psimedia library:"
        export PSIMEDIA_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
        export PSIMEDIA_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libpsimedia.dylib"
        log "Include path: '${PSIMEDIA_INCLUDE}'"
        log "Library path: '${PSIMEDIA_LIBRARY}'"
    fi
}

#####################################################################
# qca installation/detection
#####################################################################
function build_deps_qca()
{
    log "Detecting qca..."
    if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/qca.framework/Versions/Current/qca" ]; then
        log "Downloading QCA sources..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/qca"
        cd "${PSIBUILD_DEPS_DIR}/qca"
        curl -L "${DEP_QCA_SOURCE_URL}/${DEP_QCA_FILENAME}" -o "${DEP_QCA_FILENAME}"
        tar -xf "${DEP_QCA_FILENAME}"
        cd "qca-${DEP_QCA_VERSION}"
        log "Configuring QCA..."
        mkdir build && cd $_
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${PSIBUILD_DEPS_DIR}/dep_root" -DQCA_PREFIX_INSTALL_DIR="${PSIBUILD_DEPS_DIR}/dep_root" -DQT_INSTALL_LIBS="${QTDIR}" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.5 -DQT4_BUILD=ON -DBUILD_TESTS=OFF -DUSE_RELATIVE_PATHS=ON -DQT_QMAKE_EXECUTABLE="${QTDIR}/bin/qmake" ..  >> "${PSIBUILD_LOGS_DIR}/qca-configure.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "qca configuration" "${PSI_DIR}/logs/qca-configure.log"
        fi
        log "Compiling QCA..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/qca-make.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "qca compilation" "${PSI_DIR}/logs/qca-make.log"
        fi
        log "Installing QCA..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/qca-install.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "qca installation" "${PSI_DIR}/logs/qca-install.log"
        fi
    fi

    log "Found qca library:"
    export QCA_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/lib/qca.framework/Versions/Current/Headers"
    export QCA_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/qca.framework/Versions/Current/qca"
    log "Include path: '${QCA_INCLUDE}'"
    log "Library path: '${QCA_LIBRARY}'"
}

#####################################################################
# QConf installation/detection.
#####################################################################
function build_deps_qconf()
{
    # QConf.
    if [ ${QT_VERSION_MAJOR} -eq 4 ]; then
        local QCONFDIR="${PSIBUILD_DEPS_DIR}/qconf-qt4"
        export QMAKESPEC="macx-g++"
    else
        local QCONFDIR="${PSIBUILD_DEPS_DIR}/qconf-qt5"
    fi

    if [ -f "${QCONFDIR}/qconf" ]; then
        # Okay, qconf already compiled.
        QCONF="${QCONFDIR}/qconf"
        log "Found qconf binary: '${QCONF}'"
    else
        # qconf isn't found.
        log "Installing qconf..."
        mkdir -p "${QCONFDIR}" && cd $_
        if [ ! -d ".git" ]; then
            git clone "${GIT_REPO_DEP_QCONF}" .
        else
            git pull
        fi
        local qconf_conf_opts="--qtdir=${QTDIR}"
        ./configure ${qconf_conf_opts}
        if [ $? -ne 0 ]; then
            action_failed "QConf sources configuration" "None"
        fi
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/qconf-make.log" 2>&1
        if [ $? -ne 0 ]; then
            action_failed "QConf compilation" "${PSIBUILD_LOGS_DIR}/qconf-make.log"
        fi
        QCONF="${QCONFDIR}/qconf"
        log "QConf is now available at '${QCONF}'"
    fi
}

build_deps_detect_standalone