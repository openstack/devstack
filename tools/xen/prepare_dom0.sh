#i!/bin/sh
set -o xtrace
set -o errexit

# Install basics for vi and git
yum -y  --enablerepo=base install gcc make vim-enhanced zlib-devel openssl-devel curl-devel.i386

# Simple but usable vimrc
if [ ! -e /root/.vimrc ]; then
    cat > /root/.vimrc <<EOF
syntax on
se ts=4
se expandtab
se shiftwidth=4
EOF
fi

# Use the pretty vim
if [ -e /usr/bin/vim ]; then
    rm /bin/vi
    ln -s /usr/bin/vim /bin/vi
fi

# Install git 
if ! which git; then
    DEST=/tmp/
    GITDIR=$DEST/git-1.7.7
    cd $DEST
    rm -rf $GITDIR*
    wget http://git-core.googlecode.com/files/git-1.7.7.tar.gz
    tar xfv git-1.7.7.tar.gz
    cd $GITDIR
    ./configure --with-curl --with-expat
    make install
fi

