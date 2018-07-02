#!/bin/bash -xe

# basic reference point for things like filecache
#
# TODO(sdague): once we have a few of these I imagine the download
# step can probably be factored out to something nicer
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
FILES=$TOP_DIR/files
source $TOP_DIR/stackrc

# Package source and version, all pkg files are expected to have
# something like this, as well as a way to override them.
ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION:-1.7.5}
ELASTICSEARCH_BASEURL=${ELASTICSEARCH_BASEURL:-https://download.elasticsearch.org/elasticsearch/elasticsearch}

# Elastic search actual implementation
function wget_elasticsearch {
    local file=${1}

    if [ ! -f ${FILES}/${file} ]; then
        wget $ELASTICSEARCH_BASEURL/${file} -O ${FILES}/${file}
    fi

    if [ ! -f ${FILES}/${file}.sha1.txt ]; then
        wget $ELASTICSEARCH_BASEURL/${file}.sha1.txt -O ${FILES}/${file}.sha1.txt
    fi

    pushd ${FILES};  sha1sum ${file} > ${file}.sha1.gen;  popd

    if ! diff ${FILES}/${file}.sha1.gen ${FILES}/${file}.sha1.txt; then
        echo "Invalid elasticsearch download. Could not install."
        return 1
    fi
    return 0
}

function download_elasticsearch {
    if is_ubuntu; then
        wget_elasticsearch elasticsearch-${ELASTICSEARCH_VERSION}.deb
    elif is_fedora || is_suse; then
        wget_elasticsearch elasticsearch-${ELASTICSEARCH_VERSION}.noarch.rpm
    fi
}

function configure_elasticsearch {
    # currently a no op
    :
}

function _check_elasticsearch_ready {
    # poll elasticsearch to see if it's started
    if ! wait_for_service 30 http://localhost:9200; then
        die $LINENO "Maximum timeout reached. Could not connect to ElasticSearch"
    fi
}

function start_elasticsearch {
    if is_ubuntu; then
        sudo /etc/init.d/elasticsearch start
        _check_elasticsearch_ready
    elif is_fedora; then
        sudo /bin/systemctl start elasticsearch.service
        _check_elasticsearch_ready
    elif is_suse; then
        sudo /usr/bin/systemctl start elasticsearch.service
        _check_elasticsearch_ready
    else
        echo "Unsupported architecture...can not start elasticsearch."
    fi
}

function stop_elasticsearch {
    if is_ubuntu; then
        sudo /etc/init.d/elasticsearch stop
    elif is_fedora; then
        sudo /bin/systemctl stop elasticsearch.service
    elif is_suse ; then
        sudo /usr/bin/systemctl stop elasticsearch.service
    else
        echo "Unsupported architecture...can not stop elasticsearch."
    fi
}

function install_elasticsearch {
    pip_install_gr elasticsearch
    if is_package_installed elasticsearch; then
        echo "Note: elasticsearch was already installed."
        return
    fi
    if is_ubuntu; then
        is_package_installed default-jre-headless || install_package default-jre-headless

        sudo dpkg -i ${FILES}/elasticsearch-${ELASTICSEARCH_VERSION}.deb
        sudo update-rc.d elasticsearch defaults 95 10
    elif is_fedora; then
        is_package_installed java-1.8.0-openjdk-headless || install_package java-1.8.0-openjdk-headless
        yum_install ${FILES}/elasticsearch-${ELASTICSEARCH_VERSION}.noarch.rpm
        sudo /bin/systemctl daemon-reload
        sudo /bin/systemctl enable elasticsearch.service
    elif is_suse; then
        is_package_installed java-1_8_0-openjdk-headless || install_package java-1_8_0-openjdk-headless
        zypper_install --no-gpg-checks ${FILES}/elasticsearch-${ELASTICSEARCH_VERSION}.noarch.rpm
        sudo /usr/bin/systemctl daemon-reload
        sudo /usr/bin/systemctl enable elasticsearch.service
    else
        echo "Unsupported install of elasticsearch on this architecture."
    fi
}

function uninstall_elasticsearch {
    if is_package_installed elasticsearch; then
        if is_ubuntu; then
            sudo apt-get purge elasticsearch
        elif is_fedora; then
            sudo yum remove elasticsearch
        elif is_suse; then
            sudo zypper rm elasticsearch
        else
            echo "Unsupported install of elasticsearch on this architecture."
        fi
    fi
}

# The PHASE dispatcher. All pkg files are expected to basically cargo
# cult the case statement.
PHASE=$1
echo "Phase is $PHASE"

case $PHASE in
    download)
        download_elasticsearch
        ;;
    install)
        install_elasticsearch
        ;;
    configure)
        configure_elasticsearch
        ;;
    start)
        start_elasticsearch
        ;;
    stop)
        stop_elasticsearch
        ;;
    uninstall)
        uninstall_elasticsearch
        ;;
esac
