#!/usr/bin/env bash
# vi: set ts=4 :
#
# 
#The MIT License (MIT)
#
#Copyright (c) 2017 Sebastien Perreault

#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

REQUIRED_RPMS="createrepo dpkg dpkg-devel gnupg2 perl-TimeDate unzip"
SUPPORTED_EL_DISTOS="RHEL6 RHEL7 RHEL_OEL6 RHEL_OEL7"
ARCH="x86_64"
COMMON_PACKAGES="GUI Gateway"
EXCLUDED_DISTROS="UBUNTU VMware COREOS XEN SLES Windows"
COMMANDS="openssl unzip"

###
# Usage
###
usage() {
	printf "ScaleIO repo creation tool\n" 1>&2
	printf "usage: $0 [-s <src>] [-d <dest>] [-u <base_url>]\n" 1>&2
	printf "\t<src> is the complete download ei: ScaleIO_2.0.0.3_Complete_Software_Download.zip\n" 1>&2
	printf "\t<dest> is the root of your ScaleIO repo ei: /var/lib/lighttpd/repos/scaleio\n" 1>&2
	printf "\t<url> is the base url for your repo, ei: http://localhost/repos/scaleio\n" 1>&2
	exit 1
}

###
# Make sure the required RPM's are installed on the system
###
install_rpms() {
	yum install -y epel-release
	yum install -y $REQUIRED_RPMS
}

###
# Test if it's the complete package
###
test_scaleio_zip() {
	if ! [[  "${SRC}" =~ .*ScaleIO_[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}_Complete_.*\.zip$ ]]; then
		echo "This doesn't look like a Complete Download zip file" 1>&2
		usage		
	fi
	SCALEIO_BASE_FILENAME=$(basename $SRC .zip)
	local tmp_var=${SCALEIO_BASE_FILENAME//ScaleIO_/}
	SCALEIO_VERSION=${tmp_var//_Complete_Software_Download/}
	local semver=(${SCALEIO_VERSION//./ })
	SCALEIO_VERSION_MAJOR=${semver[0]}
	SCALEIO_VERSION_MINOR=${semver[1]}
	SCALEIO_VERSION_PATCH=${semver[2]}
	SCALEIO_VERSION_SPECIAL=${semver[3]}
}

###
# Create work dir to unzip the files
###
create_dir() {
	if ! [[ -d ${DEST} ]]; then
		echo "${DEST} is not a directory" 1>&2
		usage
	fi
	local test_file=${DEST}/.test.$$
	touch ${test_file}
	if [[ $? != 0 ]]; then
		echo "${DEST} is not writable" 1>&2
		usage
	fi
	rm ${test_file} 
	if [[ -d ${DEST}/${SCALEIO_VERSION} ]]; then
		echo "${DEST}/${SCALEIO_VERSION} already exist, cannot continue" 1>&2
		exit 1
	fi
	mkdir ${DEST}/${SCALEIO_VERSION}
	if [[ -h ${DEST}/${SCALEIO_VERSION_MAJOR}.${SCALEIO_VERSION_MINOR}.${SCALEIO_VERSION_PATCH} ]]; then
		echo "Already have a symlink for ${DEST}/${SCALEIO_VERSION_MAJOR}.${SCALEIO_VERSION_MINOR}.${SCALEIO_VERSION_PATCH}, Overwrite [Y/N]: " 1>&2
	    while [[ -z "${SYMLINK}" ]];
		do
			read -p "" answer
			case ${answer} in
			[yY]*)
				SYMLINK=1
				;;
			[nN]*)
				SYMLINK=0
				;;
			*)
				echo "Please answer Y or N: "
				;;
			esac
		done
	else
		# We create the first symlink
		SYMLINK=1
	fi
	WORKDIR=${DEST}/.work.$$
	mkdir ${WORKDIR}
}

###
# Clean work dir
###
clean_work_dir() {
	if [ -d ${WORKDIR} ]; then
		rm -rf ${WORKDIR}
	fi
}

###
# Check for required commands
##$
check_required_commands(){
	for c in ${COMMANDS}
	do
		if ! command -v ${c} >/dev/null; then
			echo "${c} command not found, make sure it's installed and in your PATH" 1>&2
			clean_work_dir
			exit 1
		fi  
	done
}

###
# Do the md5 checking
###
test_md5() {
	local zip_file=${WORKDIR}/${SCALEIO_BASE_FILENAME}/${1}.zip
	local md5_file=${WORKDIR}/${SCALEIO_BASE_FILENAME}/${1}.md5
	echo -n "Testing ${zip_file}'s MD5: "
	local openssl_md5_out
	openssl_md5_out=$(openssl dgst -md5 $zip_file)
	local current_md5
	current_md5=${openssl_md5_out//MD5*= /}
	local saved_md5
	saved_md5=$(cat $md5_file)
	if ! [[ ${current_md5} == ${saved_md5} ]]; then
		echo "NOT OK, check your download source" 1>&2
		exit 1
	else
		echo "OK" 
	fi
}

###
# Extract EL packages
###
extract_el_packages(){
	local repo_dir=${1}
	local unzip_dir=${2}
	for file in $(ls /${unzip_dir}/*.zip | grep -E ${SUPPORTED_EL_DISTOS//\ /|})
	do
		local base_file_name
		base_file_name=$(basename $file .zip)
		test_md5 ${base_file_name}
		unzip -d ${unzip_dir} ${file}
	   	local temp_val=(${base_file_name//_/ } 	)
		local distro=${temp_val[2]}
		if ! [[ ${distro} =~ .*[0-9] ]]; then
			distro=${distro}_${temp_val[3]}	
		fi
		local distro_dir=${repo_dir}/${distro}
		mkdir -p ${distro_dir}
		for arch in ${ARCH}
		do
			local arch_dir=${repo_dir}/${distro}/${arch}
			local rpm_dir=${arch_dir}/rpms
			mkdir -p ${rpm_dir}
			mv ${unzip_dir}/${base_file_name}/*${arch}.rpm ${rpm_dir}
			for common_package in ${COMMON_PACKAGES}
			do
				cp ${unzip_dir}/*${common_package}*/*.rpm ${rpm_dir}
			done
			createrepo --database ${arch_dir}
		done
		local readme_file=${repo_dir}/${distro}/README.txt
		touch ${readme_file}
		echo "# ScaleIO ${VERSION} ${distro} - repo " >> ${readme_file}
		echo "[scaleio]" >> ${readme_file}
		echo "name = ScaleIO" >> ${readme_file}
		echo "baseurl = ${URL}/${SCALEIO_VERSION}/${distro}/\$basearch" >> ${readme_file}
		echo "gpgkey = ${URL}/${SCALEIO_VERSION}/RPM-GPG-KEY-ScaleIO" >> ${readme_file}
		echo "# ScaleIO packages are not signed" >> ${readme_file}
		echo "gpgcheck = 0" >> ${readme_file}
	done
	#
	# copy gpgkey
	#
	unzip -d ${unzip_dir} ${unzip_dir}/ScaleIO_${SCALEIO_VERSION}_GPG-RPM-KEY_Download.zip
	for f in ${unzip_dir}/ScaleIO_${SCALEIO_VERSION}_GPG-RPM-KEY_Download/*
	do
		local gpg_base_name
		gpg_base_name=$(basename $f)	
		cp ${f} ${repo_dir}
		ln -s ${repo_dir}/${gpg_base_name} ${repo_dir}/${gpg_base_name//_*/}
	done
}


###
# unpack zip in ${WORKDIR}
###
create_repo(){
	unzip -d ${WORKDIR} ${SRC} -x *${EXCLUDED_DISTROS// /* -x *}* 
	local repo_dir=${DEST}/${SCALEIO_VERSION}
	local unzip_dir=${WORKDIR}/${SCALEIO_BASE_FILENAME}
	#
	# Extrat common packages
	#
	for file in $(ls /${unzip_dir}/*.zip | grep -E ${COMMON_PACKAGES//\ /|})
	do
		local base_file_name
		base_file_name=$(basename $file .zip)
		test_md5 ${base_file_name}
		unzip -d ${unzip_dir} ${file}
	done
	extract_el_packages ${repo_dir} ${unzip_dir}
	if [[ ${SYMLINK} == 1 ]]; then
		rm ${DEST}/${SCALEIO_VERSION_MAJOR}.${SCALEIO_VERSION_MINOR}.${SCALEIO_VERSION_PATCH}
		ln -s ${DEST}/${SCALEIO_VERSION} ${DEST}/${SCALEIO_VERSION_MAJOR}.${SCALEIO_VERSION_MINOR}.${SCALEIO_VERSION_PATCH}
		echo "New release symlinked, you can now run yum update to upgrade"
	fi
}

###
# Configure lighttpd
###
install_lighttpd(){
	#yum install -y lighttpd
	systemctl enable lighttpd
	systemctl start lighttpd
	
}
#
# Main Loop
#

while getopts ":s:d:u:" o
do
	case "${o}" in
	s)
		SRC=${OPTARG}
		;;
	d)
		DEST=${OPTARG}
		;;
	u)
		URL=${OPTARG}
		;;
	\?)
		usage
		;;
	:)
		usage
		;;
	*)
		usage
		;;
	esac
done
shift $((OPTIND-1))
if [ -z "${SRC}" ] || [ -z "${DEST}" ]; then
	usage
fi

install_rpms 
check_required_commands
test_scaleio_zip
create_dir
create_repo
clean_work_dir 
