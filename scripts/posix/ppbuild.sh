#!/bin/bash

#CONSTANTS/КОНСТАНТЫ
home=${HOME:-/home/$USER} #домашний каталог
psi_version="1.0" #не менять без необходимости, нужно для пакетирования
bindirs="/usr/bin
/usr/local/bin
${home}/bin" #список каталогов где могут быть найдены бинарники
lib_prefixes="/usr/lib
/usr/lib64
/usr/local/lib
/usr/local/lib64" #список каталогов для поиска библиотек
#guthub repositories
psi_url="https://github.com/psi-im/psi.git"
psi_plus_url="https://github.com/psi-plus/main.git"
plugins_url="https://github.com/psi-im/plugins.git"
langs_url="https://github.com/psi-plus/psi-plus-l10n.git"
#psi_cmake_url="https://github.com/psi-plus/psi-plus-cmake.git"
def_prefix="/usr" #префикс для сборки пси+
libpsibuild_url="https://raw.github.com/psi-plus/maintenance/master/scripts/posix/libpsibuild.sh"
#DEFAULT OPTIONS/ОПЦИИ ПО УМОЛЧАНИЮ
qt_ver=5
spell_flag="-DUSE_ENCHANT=OFF -DUSE_HUNSPELL=ON"
spellchek_engine="hunspell"
iswebkit=""
use_iconsets="system clients activities moods affiliations roster"
isoffline=0
skip_invalid=0
use_plugins="*"
let cpu_count=$(grep -c ^processor /proc/cpuinfo)+1
#
#COLORS
red="\e[0;31m"
green="\e[0;32m"
nocolor="\x1B[0m"
pink="\x1B[01;91m"
yellow="\x1B[01;93m"
blue="\x1B[01;94m"
#

#VARIABLES/ПЕРЕМЕННЫЕ
#каталог где будет лежать скрипт libpsibuild.sh и каталог buildpsi(по умолчанию)
workdir=${home}/github
#значение переменной buildpsi по умолчанию
default_buildpsi=${workdir}/psi 
#имя временного каталога для пакетирования
inst_suffix=tmp
#префикс CMAKE по умолчанию
DEF_CMAKE_INST_PREFIX="${home}/.local"
#каталог плагинов в префиксе по умолчанию
DEF_CMAKE_INST_SUFFIX="share/psi+/plugins"
#список плагинов для сборки через ";" (otrplugin;cleanerplugin и.т.д.)
DEF_PLUG_LIST="ALL"
#тип сборки плагинов
DEF_CMAKE_BUILD_TYPE="Release"
#Qt5
USE_QT5="ON"
#Use libpsibuild.sh to prepare sources
USE_LIBPSIBUILD=0
#Use MXE
USE_MXE=0

#WARNING: следующие переменные будут изменены в процессе работы скрипта автоматически
buildpsi=${default_buildpsi} #инициализация переменной
orig_src=${buildpsi}/build #рабочий каталог для компиляции psi+
patches=${buildpsi}/git-plus/patches #путь к патчам psi+, необходим для разработки
inst_path=${buildpsi}/${inst_suffix} #только для пакетирования
cmake_files_dir=${buildpsi}/psi-plus-cmake #файлы CMAKE для сборки плагинов
#

#ENVIRONMENT VARIABLES/ПЕРЕМЕННЫЕ СРЕДЫ
psi_datadir=${home}/.local/share/psi+
psi_cachedir=${home}/.cache/psi+
psi_homeplugdir=${psi_datadir}/plugins
#

#CONFIG FILE PATH/ПУТЬ К ФАЙЛУ НАСТРОЕК
config_file=${home}/.config/psibuild.cfg

#PLUGINS_BUILD_LOG/ЛОГ ФАЙЛ СБОРКИ ПЛАГИНОВ
plugbuild_log=${orig_src}/plugins.log
#

#RPM_VARIABLES/ПЕРЕМЕННЫЕ ДЛЯ СБОРКИ RPM ПАКЕТОВ
rpmbuilddir=${home}/rpmbuild
rpmspec=${rpmbuilddir}/SPECS
rpmsrc=${rpmbuilddir}/SOURCES
#

fetch_url ()
{
  local last_dir=$(pwd)
  local fetch_dir=""
  local f_url=""
  local fetch_log=${buildpsi}/fetch.log
  if [ ! -z "$2" ]; then
    fetch_dir=$2
  fi
  if [ ! -z "$1" ]; then
    f_url=$1
    if [ "$(ls -A ${fetch_dir})" ]; then
      cd ${fetch_dir}
      git reset --hard
      git pull
      git submodule update
      cd ${last_dir}
    else
      git clone ${f_url} ${fetch_dir}
      cd ${fetch_dir}
      git submodule init
      git submodule update
      cd ${last_dir}
    fi
  fi
}

fetch_all ()
{
  fetch_url ${psi_url} ${buildpsi}/git
  fetch_url ${psi_plus_url} ${buildpsi}/git-plus
  fetch_url ${plugins_url} ${buildpsi}/plugins
  fetch_url ${langs_url} ${buildpsi}/langs
  #fetch_url ${psi_cmake_url} ${buildpsi}/psi-plus-cmake
}

find_ccache ()
{
  local ccache_path=""
  for prefix_path in ${lib_prefixes}; do
    if [ -d "${prefix_path}/ccache/bin" ]; then
      if [ -f "${prefix_path}/ccache/bin/g++" ]; then
        ccache_path=${prefix_path}/ccache/bin
        break
      fi
    fi
  done
  
  if [ ! -z "${ccache_path}" ]; then
    echo -e "${pink}ccache utility found in :${nocolor} ${ccache_path}"; echo ""
    PATH="${ccache_path}:${PATH}"
    QMAKE_CCACHE_CMD="QMAKE_CXX=ccache g++"
  fi
}
#
quit ()
{
  exit 0
}
#
read_options ()
{
  local pluginlist=""
  if [ -f ${config_file} ]; then
    local inc=0
    while read -r line; do
      case ${inc} in
      "0" ) iswebkit=$(echo ${line});;
      "1" ) use_iconsets=$(echo ${line});;
      "2" ) isoffline=$(echo ${line});;
      "3" ) skip_invalid=$(echo ${line});;
      "4" ) pluginlist=$(echo ${line});;
      "5" ) spellchek_engine=$(echo ${line});;
      "6" ) buildpsi=$(echo ${line});;
      "7" ) qt_ver=$(echo ${line});;
      "8" ) qconf_bin=$(echo ${line});;
      esac
      let "inc+=1"
    done < ${config_file}
    if [ "$pluginlist" == "all" ]; then
      use_plugins="*"
    else
      use_plugins=${pluginlist}
    fi
    if [ -z "${buildpsi}" ]; then
      buildpsi=${default_buildpsi}
    fi
    if [ "${buildpsi:0:5}" == "\$HOME" ]; then
      buildpsi=${home}/${buildpsi:6}
    fi
  fi
  update_variables
}
#
update_variables ()
{
  orig_src=${buildpsi}/build
  patches=${buildpsi}/git-plus/patches
  inst_path=${buildpsi}/${inst_suffix}
  cmake_files_dir=${buildpsi}/psi-plus-cmake
  if [ "${qt_ver}" == "5" ]; then
    USE_QT5="ON"
  else
    USE_QT5="OFF"
  fi
  if [ "${spellchek_engine}" == "enchant" ]; then
    spell_flag="-DUSE_ENCHANT=ON -DUSE_HUNSPELL=OFF"
  fi
}
#
die() { echo "$@"; exit 1; }
#
check_dir ()
{
  if [ ! -z "$1" ]; then
    if [ ! -d "$1" ]; then
      mkdir -pv "$1"
    fi
  fi
}
#
down_all ()
{
  check_dir ${buildpsi}/git
  check_dir ${buildpsi}/git-plus
  check_dir ${buildpsi}/plugins
  #check_dir ${buildpsi}/psi-plus-cmake
  check_dir ${buildpsi}/langs
  fetch_all
}
#
patch_psi ()
{
  local patchlist=$(ls ${buildpsi}/git-plus/patches/ | grep diff)
  local patchnumber=10000
  local bdir=$(pwd)
  local msg=""
  local patchlogfile=${buildpsi}/${bdir##*/}${2##*/}_patch.log
  if [ ! -z "$1" ]; then
    patchnumber=$1
  fi
  echo "--Start patching--">${patchlogfile}
  do_patch ()
  {
    if [ ! -z "$1" ]; then
      echo "==${1##*/}==">>${patchlogfile}
      msg="${green}[OK]${nocolor}"
      patch -p1 --input=$1>>${patchlogfile} || msg="${red}[NO]${nocolor}"
      if [ "${msg}" != "${green}[OK]${nocolor}" ] && [ "${skip_patches}" == "n" ]; then
        die "Patching failed at patch $1"      
      fi
      echo -e "${1##*/} ${msg}"
    fi
  }
  if [ -z "$2" ]; then
    for patchfile in ${patchlist}; do
      if [  ${patchfile:0:4} -lt ${patchnumber} ]; then
        do_patch ${buildpsi}/git-plus/patches/${patchfile}
      fi
    done
  else
    do_patch $2
  fi
}
#
get_psi_plus_version()
{
  local rev="$(cd ${buildpsi}/git-plus/ ; git rev-parse --short HEAD)"
  local psirev="$(cd ${buildpsi}/git/ ; git rev-parse --short HEAD)"
  psi_plus_version="${psi_version}.${psirev}.${rev}"
}
#
prepare_psi_src ()
{
  if [ ! -z "$1" ]; then
    git archive --format=tar HEAD | ( cd $1 ; tar xf - )
    (
      export ddir="$1"
      git submodule foreach "( git archive --format=tar HEAD ) \
| ( cd \"${ddir}/\${path}\" ; tar xf - )"
    )
  fi
}
#
prepare_workspace ()
{
  local last_dir=$(pwd)
  echo "Deleting ${orig_src}"
  rm -rf ${orig_src}
  check_dir ${orig_src}
  cd ${buildpsi}/git
  prepare_psi_src ${orig_src}
  cd ${buildpsi}/plugins
  prepare_psi_src ${orig_src}/src/plugins
  #cd ${buildpsi}/psi-plus-cmake
  #prepare_psi_src ${orig_src}
  cp -a ${buildpsi}/git-plus/iconsets/* ${orig_src}/iconsets/
  cp -a ${buildpsi}/git-plus/app.ico ${orig_src}/win32/
  check_dir ${orig_src}/translations
  cp -a ${buildpsi}/langs/translations/*.ts ${orig_src}/translations/
  #cp -a ${buildpsi}/plugins/* ${orig_src}/src/plugins/
  #cp -a ${buildpsi}/psi-plus-cmake/* ${orig_src}/
  cd ${orig_src}
  patch_psi
  echo -e "${blue}Do you want to apply psi-new-history.patch${nocolor} ${pink}[y/n(default)]${nocolor}"
  read ispatch
  if [ "${ispatch}" == "y" ]; then
    cd ${orig_src}
    patch_psi 10000 ${patches}/dev/psi-new-history.patch
    cd ${workdir}
  fi
  get_psi_plus_version
  cd ${buildpsi}/git-plus
  local suffix=""
  local builddate=$(LANG=en date +'%F')
  if [ ! -z "${iswebkit}" ]; then
    suffix="-webkit"
  fi
  local ver="${psi_plus_version}${suffix} (${builddate})"
  echo $ver > ${orig_src}/version
}
#
prepare_src ()
{
  down_all
  prepare_workspace
}
#
backup_tar ()
{
  echo "Backup ${buildpsi##*/} into ${buildpsi%/*}/${buildpsi##*/}.tar.gz started..."
  cd ${buildpsi%/*}
  tar -pczf ${buildpsi##*/}.tar.gz ${buildpsi##*/}
  echo "Backup finished..."; echo " "
}
#
prepare_tar ()
{
  check_dir ${rpmbuilddir}
  check_dir ${rpmsrc}
  check_dir ${rpmspec}
  echo "Preparing Psi+ source package to build RPM..."
  get_psi_plus_version
  local tar_name=psi-plus-${psi_plus_version}
  local new_src=${buildpsi}/${tar_name}
  cp -r ${orig_src} ${new_src}
  if [ -d ${new_src} ]; then
    cd ${buildpsi}
    tar -sczf ${tar_name}.tar.gz ${tar_name}
    rm -r -f ${new_src}
    if [ -d ${rpmsrc} ]; then
      if [ -f "${rpmsrc}/${tar_name}.tar.gz" ]; then
        rm -f ${rpmsrc}/${tar_name}.tar.gz
      fi
      cp -f ${buildpsi}/${tar_name}.tar.gz ${rpmsrc}
    fi
    echo "Preparing completed"
  fi
}
#
compile_psiplus ()
{
  curd=$(pwd)
  prepare_src
  cd ${orig_src}
  local buildlog=${buildpsi}/build.log
  echo "***Build started***">${buildlog}
  check_dir ${orig_src}/cbuild
  cd ${orig_src}/cbuild
  flags="-DCMAKE_BUILD_TYPE=${DEF_CMAKE_BUILD_TYPE} -DUSE_QT5=${USE_QT5}"
  if [ ! -z "$1" ]; then
    flags="${flags} -DCMAKE_INSTALL_PREFIX=$1"
  else
    flags="${flags}"
  fi
  if [ -z "${iswebkit}" ]; then
    flags="${flags} -DENABLE_WEBKIT=OFF"
  fi
  get_psi_plus_version
  cd ${orig_src}/cbuild
  flags="${flags} -DPSI_PLUS_VERSION=${psi_plus_version}"
  cbuild_path=".."
  if [ ! -z "$2" ]; then
    cbuild_path=$2
  fi
  echo "--Starting cmake 
  cmake ${flags} ${cbuild_path}">>${buildlog}
  cmake ${flags} ${cbuild_path}
  echo "--Starting psi-plus compilation">>${buildlog}
  cmake --build . --target all -- -j${cpu_count} 2>>${buildlog} || echo -e "${red}There were errors. Open ${buildpsi}/build.log to see${nocolor}"
  echo "***Build finished***">>${buildlog}
  if [ -z "$1" ]; then
    cmake --build . --target prepare-bin
    echo "Psi+ installed in ${orig_src}/cbuild/psi">>${buildlog}
  fi
  cd ${curd}
}
#
fetch_cmake_files ()
{
  local repo_url="https://github.com/Vitozz/psi-plus-cmake.git"
  fetch_url ${repo_url} ${cmake_files_dir}
  cd ${buildpsi}
}
#
build_cmake_plugins ()
{
  echo_done() {
    echo " "
    echo "********************************"
    echo "Plugins installed succesfully!!!"
    echo "********************************"
    echo " "
  }
  local pl_preffix=${DEF_CMAKE_INST_PREFIX}
  local pl_suffix=${DEF_CMAKE_INST_SUFFIX}
  if [ ! -f "${orig_src}/psi.pro" ]; then
    prepare_src
  fi
  check_dir ${orig_src}
  #fetch_cmake_files
  #cp -rf ${cmake_files_dir}/* ${orig_src}/
  cd ${orig_src}
  local b_dir=${orig_src}/build
  check_dir ${b_dir}
  cd ${b_dir}
  echo -e "${blue}Do you want to install psi+ plugins into ${psi_homeplugdir}${nocolor} ${pink}[y/n(default)]${nocolor}"
  read isinstall
  if [ "${isinstall}" != "y" ]; then
    pl_preffix=${orig_src}
    pl_suffix="plugins"
  fi  
  local cmake_flags="-DCMAKE_BUILD_TYPE=${DEF_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${pl_preffix} -DONLY_PLUGINS=ON -DPLUGINS_PATH=${pl_suffix} -DBUILD_PLUGINS=${DEF_PLUG_LIST} -DBUILD_DEV=OFF -DUSE_QT5=${USE_QT5}"
  echo " "; echo "Build psi+ plugins using CMAKE started..."; echo " "
  cmake ${cmake_flags} ..
  make -j${cpu_count} && make install && echo_done
  cd ${orig_src}
  rm -rf ${b_dir}
}
#
build_deb_package ()
{
  compile_psiplus /usr ${orig_src}
  echo "Building Psi+ DEB package with checkinstall"
  get_psi_plus_version
  local desc='Psi is a cross-platform powerful Jabber client (Qt, C++) designed for the Jabber power users.
Psi+ - Psi IM Mod by psi-dev@conference.jabber.ru.'
  cd ${orig_src}
  echo "${desc}" > description-pak
  #make spellcheck
  local spell_dep=""
  if [ "${spellchek_engine}" == "hunspell" ]; then
    spell_dep="libhunspell-1.3-0"
  else
    spell_dep="libenchant1c2a"
  fi
  if [ "${qt_ver}" == "4" ]; then
    local webkitdep=""
    if [ ! -z "${iswebkit}" ]; then
      webkitdep=", libqt4-webkit '(>=4.4.3)'"
    fi
    qt_deps="libqt4-dbus '(>=4.4.3)', libqt4-network '(>=4.4.3)', libqt4-qt3support '(>=4.4.3)', libqt4-xml '(>=4.4.3)', libqtcore4 '(>=4.4.3)', libqtgui4 '(>=4.4.3)'${webkitdep}"
  else
    local webkitdep=""
    if [ ! -z "${iswebkit}" ]; then
      webkitdep=", libqt5webkit5"
    fi
    qt_deps="libqt5dbus5, libqt5network5, libqt5xml5 , libqt5core5a, libqt5gui5, libqt5widgets5, libqt5x11extras5${webkitdep}"
  fi
  local requires=" ${spell_dep}, 'libc6 (>=2.7-1)', 'libgcc1 (>=1:4.1.1)', 'libqca2', ${qt_deps}, 'libstdc++6 (>=4.1.1)', 'libx11-6', 'libxext6', 'libxss1', 'zlib1g (>=1:1.1.4)' "
  sudo checkinstall -D --nodoc --pkgname=psi-plus --pkggroup=net --pkgversion=${psi_plus_version} --pkgsource=${orig_src} --maintainer="thetvg@gmail.com" --requires="${requires}"
  cp -f ${orig_src}/*.deb ${buildpsi}
}
#
prepare_spec ()
{
  get_psi_plus_version
  if [ -z "${iswebkit}" ]; then
    extraflags="-DENABLE_WEBKIT=OFF ${spell_flag}"
  fi
  echo "Creating psi.spec file..."
  local specfile="Summary: Client application for the Jabber network
Name: psi-plus
Version: ${psi_plus_version}
Release: 1
License: GPL
Group: Applications/Internet
URL: http://code.google.com/p/psi-dev/
Source0: %{name}-%{version}.tar.gz


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root


BuildRequires: openssl-devel, gcc-c++, zlib-devel
%{!?_without_freedesktop:BuildRequires: desktop-file-utils}


%description
Psi is the premiere Instant Messaging application designed for Microsoft Windows, 
Apple Mac OS X and GNU/Linux. Built upon an open protocol named Jabber,           
si is a fast and lightweight messaging client that utilises the best in open      
source technologies. The goal of the Psi project is to create a powerful, yet     
easy-to-use Jabber/XMPP client that tries to strictly adhere to the XMPP drafts.  
and Jabber JEPs. This means that in most cases, Psi will not implement a feature  
unless there is an accepted standard for it in the Jabber community. Doing so     
ensures that Psi will be compatible, stable, and predictable, both from an end-user 
and developer standpoint.
Psi+ - Psi IM Mod by psi-dev@conference.jabber.ru


%prep
%setup


%build
cmake -DCMAKE_INSTALL_PREFIX=\"%{_prefix}\" -DCMAKE_BUILD_TYPE=Release ${extraflags} .
%{__make} %{?_smp_mflags}


%install
%{__rm} -rf %{buildroot}


%{__make} install INSTALL_ROOT=\"%{buildroot}\"


# Install the pixmap for the menu entry
%{__install} -Dp -m0644 iconsets/system/default/logo_128.png \
    %{buildroot}%{_datadir}/pixmaps/psi-plus.png ||:               

mkdir -p %{buildroot}%{_datadir}/psi-plus
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications

%post
touch --no-create %{_datadir}/icons/hicolor || :
%{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :


%postun
touch --no-create %{_datadir}/icons/hicolor || :
%{_bindir}/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor || :


%clean
%{__rm} -rf %{buildroot}


%files
%defattr(-, root, root, 0755)
%doc COPYING README TODO
%{_bindir}/psi-plus
#%{_bindir}/psi-plus.debug
%{_datadir}/psi-plus/
%{_datadir}/pixmaps/psi-plus.png
%{_datadir}/applications/psi-plus.desktop
%{_datadir}/icons/hicolor/*/apps/psi-plus.png
%exclude %{_datadir}/psi-plus/COPYING
%exclude %{_datadir}/psi-plus/README
"
  local tmp_spec=${buildpsi}/test.spec
  usr_spec=${rpmspec}/psi-plus.spec
  echo "${specfile}" > ${tmp_spec}
  cp -f ${tmp_spec} ${usr_spec}
}
#
build_rpm_package ()
{
  prepare_src
  prepare_tar
  get_psi_plus_version
  local tar_name=psi-plus-${psi_plus_version}
  local sources=${rpmsrc}
  if [ -f "${sources}/${tar_name}.tar.gz" ]; then
    prepare_spec
    echo "Building Psi+ RPM package"
    cd ${rpmspec}
    rpmbuild -ba --clean --rmspec --rmsource ${usr_spec}
    local rpm_ready=$(find $HOME/rpmbuild/RPMS | grep psi-plus)
    local rpm_src_ready=$(find $HOME/rpmbuild/SRPMS | grep psi-plus)
    cp -f ${rpm_ready} ${buildpsi}
    cp -f ${rpm_src_ready} ${buildpsi}
  fi
}
#
prepare_dev ()
{
  local psidev=${buildpsi}/psidev
  local orig=${psidev}/git.orig
  local new=${psidev}/git
  rm -rf ${orig}
  rm -rf ${new}
  cd ${buildpsi}
  echo ${psidev}
  check_dir ${psidev}
  check_dir ${orig}
  check_dir ${new}
  if [ ! -d ${buildpsi}/git ]; then
    down_all
  fi
  cd ${buildpsi}/git
  prepare_psi_src ${orig}
  prepare_psi_src ${new}
  cd ${psidev}
  if [ ! -f psidiff.ignore ]; then
    wget --no-check-certificate "https://raw.github.com/psi-plus/maintenance/master/scripts/posix/psidiff.ignore" || die "Failed to update psidiff.ignore";
  fi
  if [ ! -f "${psidev}/mkpatch" ]; then
    local mkpatch="#!/bin/bash
diff -urpN -X "psidiff.ignore" git.orig git | sed '/\(.*айлы.*различаются\|Binary.*differ\)\|^diff -urpN/d' | sed 's/^\(\(---\|+++\)\s\+\S\+\).*/\1/'
"
    echo "${mkpatch}">${psidev}/mkpatch
    chmod u+x ${psidev}/mkpatch
  fi
  local patchlist=$(ls ${buildpsi}/git-plus/patches/ | grep diff)
  cd ${orig}
  echo "---------------------
Patching original src
---------------------">${buildpsi}/${orig##*/}_patching.log
  echo -e "${blue}Enter maximum patch number to patch orig src${nocolor}"
  read patchnumber
  if [ ! -z "$patchnumber" ]; then
    patch_psi $patchnumber
  fi
  cd ${new}
  echo "---------------------
Patching work src
---------------------">>${buildpsi}/${new##*/}_patching.log
  echo -e "${blue}Enter maximum patch number to patch work src${nocolor}"
  read patchnumber
  if [ ! -z "$patchnumber" ]; then
    patch_psi $patchnumber
  fi
}
#
prepare_plugins_spec ()
{
  local specfile="
Summary: ${summary}
Name: ${progname}
Version: ${rpmver}
Release: 1
License: GPL-2
Group: ${group}
URL: ${urlpath}
Source0: ${package_name}
BuildRequires: ${breq}
Requires: psi-plus
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-build

%description
${desc}

%prep
%setup

%build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%{buildroot}%{_libdir} -DUSE_QT5=${USE_QT5} -DONLY_PLUGINS=ON -DPLUGINS_PATH=/psi-plus/plugins .
%{__make} %{?_smp_mflags} 

%install
[ \"%{buildroot}\" != \"/\"] && rm -rf %{buildroot}
%{__make} install INSTALL_ROOT=\"%{buildroot}\"

if [ \"%{_target_cpu}\" = \"x86_64\" ] && [ -d \"/usr/lib64\" ]; then
  mkdir -p %{buildroot}/usr/lib64
else
  mkdir -p %{buildroot}/usr/lib
fi

%clean
[ \"%{buildroot}\" != \"/\" ] && rm -rf %{buildroot}

%files
%{_libdir}/psi-plus/plugins
"
  echo "${specfile}" > ${rpmspec}/${progname}.spec
}
#
build_rpm_plugins ()
{
  local progname="psi-plus-plugins"
  #fetch_cmake_files
  prepare_src
  check_dir ${orig_src}
  #cp -rf ${cmake_files_dir}/* ${orig_src}/
  cd ${buildpsi}
  get_psi_plus_version
  local rpmver=${psi_plus_version}
  local allpluginsdir=${buildpsi}/${progname}-${rpmver}
  local package_name="${progname}-${rpmver}.tar.gz"
  local summary="Plugins for psi-plus-${rpmver}"
  local breq="libotr2-devel, libtidy-devel, libgcrypt-devel, libgpg-error-devel"
  local urlpath="https://github.com/psi-plus/plugins"
  local group="Applications/Internet"
  local desc="Plugins for jabber-client Psi+"
  check_dir ${allpluginsdir}
  cp -r ${orig_src}/* ${allpluginsdir}/
  cd ${buildpsi}
  tar -pczf $package_name ${progname}-${rpmver}
  prepare_plugins_spec
  cp -rf ${package_name} ${rpmsrc}/
  rpmbuild -ba --clean --rmspec --rmsource ${rpmspec}/${progname}.spec
  echo "Cleaning..."
  cd ${buildpsi}
  rm -rf ${allpluginsdir}
}
#
get_resources ()
{
  fetch_url "https://github.com/psi-plus/resources.git" ${buildpsi}/resources
}
#
install_resources ()
{
  cd ${buildpsi}
  check_dir ${psi_datadir}
  if [ ! -d "resources" ]; then
    get_resources
  fi
  cp -rf ${buildpsi}/resources/* ${psi_datadir}/
}
#
install_iconsets ()
{
  cd ${buildpsi}
  check_dir ${psi_datadir}
  if [ -d "resources" ]; then
    get_resources
  fi  
  cp -rf ${buildpsi}/resources/iconsets ${psi_datadir}/
}
#
install_skins ()
{
  cd ${buildpsi}
  check_dir ${psi_datadir}
  if [ -d "resources" ]; then
    cp -rf ${buildpsi}/resources/skins ${psi_datadir}/
  else
    get_resources
    cp -rf ${buildpsi}/resources/skins ${psi_datadir}/
  fi 
}
#
install_sounds ()
{
  cd ${buildpsi}
  check_dir ${psi_datadir}
  if [ -d "resources" ]; then
    cp -rf ${buildpsi}/resources/sound ${psi_datadir}/
  else
    get_resources
    cp -rf ${buildpsi}/resources/sound ${psi_datadir}/
  fi 
}
#
install_themes ()
{
  cd ${buildpsi}
  check_dir ${psi_datadir}
  if [ -d "resources" ]; then
    cp -rf ${buildpsi}/resources/themes ${psi_datadir}/
  else
    get_resources
    cp -rf ${buildpsi}/resources/themes ${psi_datadir}/
  fi 
}
#
update_resources ()
{
  get_resources
}
#
build_locales ()
{
  local tr_path=${buildpsi}/langs/translations
  fetch_all
  if [ -d "${tr_path}" ]; then
    rm -f ${tr_path}/*.qm
    if [ -f "/usr/bin/qtchooser" ];then
      lrelease -qt=${qt_ver} ${tr_path}/*.ts
    elif [ -f "/usr/bin/lrelease" ] || [ -f "/usr/local/bin/lrelease" ]; then
      lrelease ${tr_path}/*.ts 
    elif [ -f "/usr/bin/lrelease-qt4" ] || [ -f "/usr/local/bin/lrelease-qt4" ]; then
      lrelease-qt4 ${tr_path}/*.ts 
    fi
  fi 
}
#
install_locales ()
{
  local tr_path=${buildpsi}/langs/translations
  build_locales
  check_dir ${psi_datadir}
  cp -rf ${tr_path}/*.qm ${psi_datadir}/
}
#
run_psiplus ()
{
  local psi_binary_path=${orig_src}/cbuild/psi
  if [ -f "${psi_binary_path}/psi-plus" ];then
    cd ${psi_binary_path}
    ./psi-plus
  else
    echo -e "${red}Psi+ binary not found in ${psi_binary_path}. Try to compile it first.${nocolor}"
  fi
}
#
debug_psi ()
{
  local psi_binary_path=${orig_src}/cbuild/psi
  if [ -f "${psi_binary_path}/psi-plus" ];then
    cd ${psi_binary_path}
    gdb ./psi-plus
  else
    echo -e "${red}Psi+ binary not found in ${psi_binary_path}. Try to compile it first.${nocolor}"
  fi
}
#
prepare_mxe()
{
	unset `env | \
	grep -vi '^EDITOR=\|^HOME=\|^LANG=\|MXE\|^PATH=' | \
	grep -vi 'PKG_CONFIG\|PROXY\|^PS1=\|^TERM=' | \
	cut -d '=' -f1 | tr '\n' ' '`
	export PATH="/home/vitaly/virtualka/mxe/usr/bin:$PATH"
}
run_mxe_cmake()
{
  prepare_mxe
  i686-w64-mingw32.shared-cmake $@
}
run_mxe_cmake_64()
{
  prepare_mxe
  x86_64-w64-mingw32.shared-cmake $@
}
#
compile_psi_mxe()
{
  curd=$(pwd)
  prepare_src
  mxe_rootd=${buildpsi}/mxe_builds
  check_dir ${mxe_rootd}
  cd ${orig_src}
  get_psi_plus_version
  flags="-DENABLE_PLUGINS=ON -DPRODUCTION=ON -DUSE_CCACHE=OFF"
  flags="${flags} -DPSI_PLUS_VERSION=${psi_plus_version}"
  prepare_libdir=${buildpsi}/mxe_prepare/i386
  prepare_qt_libdir=${buildpsi}/mxe_prepare/Qt5/i386
  if [ "$1" == "qt5" ];then
    cmakecmd=run_mxe_cmake
    flags="${flags} -DUSE_QT5=ON -DBUILD_ARCH=i386"
  elif [ "$1" == "qt5_64" ];then
    cmakecmd=run_mxe_cmake_64
    flags="${flags} -DUSE_QT5=ON -DBUILD_ARCH=x86_64"
  fi
  flags="${flags} -DCMAKE_INSTALL_PREFIX=${mxe_rootd}/$1"
  wrkdir=${orig_src}/cbuild4
  check_dir ${wrkdir}
  cd ${wrkdir}
  echo "--Starting cmake
  ${cmakecmd} ${flags} ${orig_src}"
  ${cmakecmd} ${flags} ${orig_src}
  echo 
  echo "Press Enter to continue..." && read tmpvar
  ${cmakecmd} --build . --target all -- -j${cpu_count}
  ${cmakecmd} --build . --target prepare-bin --
  ${cmakecmd} --build . --target prepare-bin-libs --
  check_dir ${mxe_rootd}/$1
  cp -rf ${wrkdir}/psi/*  ${mxe_rootd}/$1/
  cp -a ${wrkdir}/psi/translations ${mxe_rootd}/$1/
  cp -a ${buildpsi}/mxe_prepare/myspell ${mxe_rootd}/$1/
  #cp -a ${prepare_libdir}/* ${mxe_rootd}/$1/
  #cp -a ${prepare_qt_libdir}/* ${mxe_rootd}/$1/
  cd ${curd}
}
#
archivate_psi()
{
  get_psi_plus_version
  mxe_rootd=${buildpsi}/mxe_builds
  7z a -mx=9 -m0=LZMA -mmt=on ${mxe_rootd}/psi-plus-webkit-${psi_plus_version}-$1.7z ${mxe_rootd}/$1/*
}
#
build_all_mxe()
{
  compile_psi_mxe qt5
  compile_psi_mxe qt5_64
  archivate_all
}
#
archivate_all()
{
  archivate_psi qt5
  archivate_psi qt5_64
}
#
set_config ()
{
  local use_webkit="n"
  if [ ! -z "$iswebkit" ]; then
    use_webkit="y"
  else
    use_webkit="n"
  fi
  local is_offline="n"
  if [ "$isoffline" -eq 0 ]; then
    is_offline="n"
  else
    is_offline="y"
  fi
  local skip_patches="n"
  if [ "$skip_invalid" -eq 0 ]; then
    skip_patches="n"
  else
    skip_patches="y"
  fi
  local loop=1
  while [ ${loop} = 1 ];  do
    echo -e "${blue}Choose action TODO:${nocolor}
--${pink}[1]${nocolor} - Set WebKit version to use (current: ${use_webkit})
--${pink}[2]${nocolor} - Set iconsets list needed to build
--${pink}[3]${nocolor} - Skip Invalid patches (current: ${skip_patches})
--${pink}[4]${nocolor} - Set list of plugins needed to build (for all use *)
--${pink}[5]${nocolor} - Set psi+ spellcheck engine (current: ${spellchek_engine})
--${pink}[6]${nocolor} - Set psi+ sources path (current: ${buildpsi})
--${pink}[7]${nocolor} - Set qt version 4/5 (current: ${qt_ver})
--${pink}[8]${nocolor} - Print option values
--${pink}[0]${nocolor} - Do nothing"
    read deistvo
    case ${deistvo} in
      "1" ) echo -e "Do you want use WebKit ${pink}[y/n]${nocolor} ?"
            read variable
            if [ "$variable" == "y" ]; then
              iswebkit="--enable-webkit"
              use_webkit="y"
            else
              iswebkit=""
              use_webkit="n"
            fi;;
      "2" ) echo "Please enter iconsets separated by space"
            read variable
            if [ ! -z "$variable" ]; then
              use_iconsets=${variable}
            else
              use_iconsets="system clients activities moods affiliations roster"
            fi;;
      "3" ) echo -e "Do you want to skip invalid patches when patching ${pink}[y/n]${nocolor} ?"
            read variable
            if [ "$variable" == "y" ]; then
              skip_invalid=1
              skip_patches="y"
            else
              skip_invalid=0
              skip_patches="n"
            fi;;
      "4" ) echo "Please enter plugins needed to build separated by space (* for all)"
            read variable
            if [ ! -z "$variable" ]; then
              use_plugins=${variable}
            else
              use_plugins=""
            fi;;
      "5" ) echo -e "Please set spellcheck engine for psi+. Available values:${pink}
hunspell
enchant
${nocolor} ?"
            read variable
            if [ ! -z "$variable" ]; then
              spellchek_engine=$variable
            fi;;
      "6" ) echo "Please set psi+ sources path (absolute path, or \$HOME/path)"
            read variable
            if [ ! -z "${variable}" ]; then
              if [ "${variable:0:5}" == "\$HOME" ]; then
                buildpsi=${home}/${variable:6}
              else
                buildpsi=${variable}
              fi
            else
              buildpsi=${default_buildpsi}
            fi;;
      "7" ) echo "Please set qt version 4 or 5"
            read variable
            if [ ! -z "${variable}" ]; then
              qt_ver=${variable}
            fi;;
      "8" ) echo -e "${blue}==Options==${nocolor}
${green}WebKit${nocolor} = ${yellow}${use_webkit}${nocolor}
${green}Iconsets${nocolor} = ${yellow}${use_iconsets}${nocolor}
${green}Skip Invalid Patches${nocolor} = ${yellow}${skip_patches}${nocolor}
${green}Plugins${nocolor} = ${yellow}${use_plugins}${nocolor}
${green}Spellcheck engine${nocolor} = ${yellow}${spellchek_engine}${nocolor}
${green}Qt Version${nocolor} = ${yellow}${qt_ver}${nocolor}
${green}Psi+ sources path${nocolor} = ${yellow}${buildpsi}${nocolor}
${blue}===========${nocolor}";;
      "0" ) clear
            loop=0;;
    esac
  done
  echo "$iswebkit" > ${config_file}
  echo "$use_iconsets" >> ${config_file}
  echo "$isoffline" >> ${config_file}
  echo "$skip_invalid" >> ${config_file}
  if [ "$use_plugins" == "*" ]; then
    echo "all" >> ${config_file}
  else
    echo "$use_plugins" >> ${config_file}
  fi
  echo "$spellchek_engine" >> ${config_file}
  echo "$buildpsi" >> ${config_file}
  echo "$qt_ver" >> ${config_file}
  echo "$qconf_bin" >> ${config_file}
  update_variables
}
#
print_menu ()
{
  echo -e "${blue}Choose action TODO!${nocolor}
${pink}[1]${nocolor} - Download All needed source files to build psi+
${pink}[2]${nocolor} - Prepare psi+ sources
${pink}[3]${nocolor} - Build psi+ binary
---${pink}[31]${nocolor} - Build psi+ plugins using CMAKE
${pink}[4]${nocolor} - Build Debian package with checkinstall
${pink}[5]${nocolor} - Build openSUSE RPM-package
---${pink}[51]${nocolor} - Build plugins openSUSE RPM-package
${pink}[6]${nocolor} - Set libpsibuild options
${pink}[7]${nocolor} - Prepare psi+ sources for development
${pink}[8]${nocolor} - Get help on additional actions
${pink}[9]${nocolor} - Run compiled psi-plus binary
${pink}[0]${nocolor} - Exit"
}
#
get_help ()
{
  echo -e "${red}---------------HELP-----------------------${nocolor}
${pink}[ia]${nocolor} - Install all resources to $psi_datadir
${pink}[ii]${nocolor} - Install iconsets to $psi_datadir
${pink}[is]${nocolor} - Install skins to $psi_datadir
${pink}[iz]${nocolor} - Install sounds to to $psi_datadir
${pink}[it]${nocolor} - Install themes to $psi_datadir
${pink}[il]${nocolor} - Install locales to $psi_datadir
${pink}[bl]${nocolor} - Just build locale files without installing
${pink}[ur]${nocolor} - Update resources
${pink}[bs]${nocolor} - Backup ${buildpsi##*/} directory in ${buildpsi%/*}
${pink}[pw]${nocolor} - Prepare psi+ workspace (clean ${buildpsi}/build dir)
${pink}[dp]${nocolor} - Run psi-plus binary under gdb debugger
${red}-------------------------------------------${nocolor}
${blue}Press Enter to continue...${nocolor}"
  read
}
#
choose_action ()
{
  read vibor
  case ${vibor} in
    "1" ) down_all;;
    "2" ) prepare_src;;
    "3" ) compile_psiplus /usr;;
    "31" ) build_cmake_plugins;;
    "32" ) compile_psi_mxe qt5;;
    "33" ) compile_psi_mxe qt5_64;;
    "4" ) build_deb_package;;
    "5" ) build_rpm_package;;
    "51" ) build_rpm_plugins;;
    "6" ) set_config;;
    "7" ) prepare_dev;;
    "8" ) get_help;;
    "9" ) run_psiplus;;
    "ia" ) install_resources;;
    "ii" ) install_iconsets;;
    "is" ) install_skins;;
    "iz" ) install_sounds;;
    "it" ) install_themes;;
    "ur" ) update_resources;;
    "il" ) install_locales;;
    "bl" ) build_locales;;
    "bs" ) backup_tar;;
    "pw" ) prepare_workspace;;
    "dp" ) debug_psi;;
    "bam" ) build_all_mxe;;
    "aa" ) archivate_all;;
    "0" ) quit;;
  esac
}
#
cd ${workdir}
read_options
if [ ! -f "${config_file}" ]; then
  set_config
fi
find_ccache
clear
#
while true; do
  print_menu
  choose_action
done
exit 0
