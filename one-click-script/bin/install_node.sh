#!/bin/bash
. ./public.sh
. ./install_version.sh
node_install(){

	mv ${tar_dir}/* ${home_dir}
	add_sys_env "NODE_HOME=${home_dir} PATH=\${NODE_HOME}/bin:\$PATH"
	${home_dir}/bin/npm config set registry https://registry.npm.taobao.org
}

install_version node
install_selcet
install_dir_set
download_unzip
node_install
clear_install

