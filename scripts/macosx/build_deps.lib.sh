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
	build_deps_qconf
	build_deps_minizip
    build_deps_libidn
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
    else
        log "Detected GStreamer library:"
        export GST_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
        export GST_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libgstbase-0.10.0.dylib"
        log "Include path: '${GST_INCLUDE}'"
        log "Library path: '${GST_LIBRARY}'"
    fi
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
    else
        log "Detected Growl library:"
        export GROWL_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/lib/Growl.framework/Versions/A/Headers"
        export GROWL_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/Growl.framework/Versions/A/Growl"
        log "Include path: '${GROWL_INCLUDE}'"
        log "Library path: '${GROWL_LIBRARY}'"
    fi
}

#####################################################################
# libidn installation/detection
#####################################################################
function build_deps_libidn()
{
    log "Detecting libidn..."
    if [ ! -f "${PSIBUILD_DEPS_DIR}/dep_root/lib/libidn.dylib" ]; then
        log "Downloading libidn source..."
        mkdir -p "${PSIBUILD_DEPS_DIR}/libidn"
        cd "${PSIBUILD_DEPS_DIR}/libidn"
        curl -L "${DEP_LIBIDN_SOURCE_URL}/${DEP_LIBIDN_FILENAME}" -o "${DEP_LIBIDN_FILENAME}"
        tar -xf "${DEP_LIBIDN_FILENAME}"
        cd "libidn-${DEP_LIBIDN_VERSION}"
        log "Configuring libidn..."
        ./configure --disable-dependency-tracking --prefix="${PSIBUILD_DEPS_DIR}/dep_root" --disable-csharp >> "${PSIBUILD_LOGS_DIR}/libidn-configure.log" 2>&1
        log "Compiling libidn..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/libidn-make.log" 2>&1
        log "Installing libidn..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/libidn-install.log" 2>&1
    else
        log "Found libidn library:"
        export LIBIDN_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
        export LIBIDN_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libidn.dylib"
        log "Include path: '${LIBIDN_INCLUDE}'"
        log "Library path: '${LIBIDN_LIBRARY}'"
    fi
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
        log "Compiling ZLib..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/zlib-make.log" 2>&1
        cd contrib/minizip
        # Sed magic from https://github.com/Homebrew/homebrew-core/blob/master/Formula/minizip.rb
        log "Executing sed magic..."
        sed -i "" "s/\-L\$\(zlib_top_builddir\)/\$\(zlib_top_builddir\)\/libz.a/" Makefile.am
        sed -i "" "s/\-version\-info\ 1\:0\:0\ \-lz/\-version\-info\ 1\:0\:0/" Makefile.am
        sed -i "" "s/libminizip.la\ \-lz/libminizip.la/" Makefile.am
        log "Configuring minizip..."
        autoreconf -fi  >> "${PSIBUILD_LOGS_DIR}/minizip-configure.log" 2>&1
        ./configure --prefix="${PSIBUILD_DEPS_DIR}/dep_root" >> "${PSIBUILD_LOGS_DIR}/minizip-configure.log" 2>&1
        log "Compiling minizip..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/minizip-make.log" 2>&1
        log "Installing minizip..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/minizip-install.log" 2>&1
	else
		log "Found minizip library:"
        export MINIZIP_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/include"
        export MINIZIP_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/libminizip.dylib"
        log "Include path: '${MINIZIP_INCLUDE}'"
        log "Library path: '${MINIZIP_LIBRARY}'"
	fi
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
        log "Compiling QCA..."
        ${MAKE} ${MAKEOPTS} >> "${PSIBUILD_LOGS_DIR}/qca-make.log" 2>&1
        log "Installing QCA..."
        ${MAKE} install >> "${PSIBUILD_LOGS_DIR}/qca-install.log" 2>&1
    else
        log "Found minizip library:"
        export QCA_INCLUDE="${PSIBUILD_DEPS_DIR}/dep_root/lib/qca.framework/Versions/Current/Headers"
        export QCA_LIBRARY="${PSIBUILD_DEPS_DIR}/dep_root/lib/qca.framework/Versions/Current/qca"
        log "Include path: '${QCA_INCLUDE}'"
        log "Library path: '${QCA_LIBRARY}'"
    fi
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