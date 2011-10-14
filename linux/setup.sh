#!/bin/bash
operating_system=`uname -s`

#
# Greetings.
#
echo "Welcome to mvStore!"
echo ""
echo "Prior to running this setup, please make sure to:"
echo ""
echo "   - have a personal github account"
echo "   - be registered as contributor for mvStore (email maxw@vmware.com)"
echo "   - have a ssh keypair properly configured"
echo "   - be a sudoer"
echo ""  
echo "This setup script will perform the following steps:"
echo ""
echo "   1. create a mvStore directory that will contain the installed components"
echo "   2. check external dependencies such as cmake, curl, node.js etc."
echo "      (install them if not present)"
echo "   3. clone the mvStore projects from github"
echo "   4. fetch protobuf-2.3.0 from google and build it"
echo "   5. fetch protobuf-for-node and build it"
echo "   6. build mvStore"
echo "   7. (optional) start the mvStore server"
echo ""
echo "OS: $operating_system"
read -p "Ready to start? [Y/n]"
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "   cancelling setup upon user's request"
  exit 1
fi

#
# Create a mvStore directory to contain everything.
#
echo -e "\n1. Creating mvStore...\n"
mkdir -p mvStore
cd mvStore
echo "   $PWD"
sleep 1

#
# Check dependencies and install missing elements.
#
function install_osx_dmg
{
  curl -o $1.dmg $2
  hdiutil attach ./$1.dmg -mountpoint ./$1_volume
  pkg=`find ./$1_volume -regex .*\.pkg`
  for iP in ${pkg[@]}; do
    echo "installing package: $iP"
	sudo installer -pkg $iP -target /
  done
  hdiutil detach $1_volume
}
dependencies_exe=(cmake curl git hg node gcc)
dependencies_pkg_apt=(cmake curl git-core mercurial libssl-dev)
dependencies_pkg_yum=(cmake curl git-core mercurial openssl-devel gcc-c++)
echo -e "\n2. Checking dependencies: ${dependencies_exe[@]}\n"
sleep 1
dependencies_doinstall=0
for iD in ${dependencies_exe[@]}; do
  if ! grep '/usr/' <(which $iD) >/dev/null; then
    echo "   * $iD is not present - will install"
    dependencies_doinstall=1
  fi
done
if [ $dependencies_doinstall -eq 1 ]; then
  read -p "   -> Ready to install missing dependencies? [Y/n]"
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "   cancelling setup upon user's request"
    exit 1
  fi
  
  # Standard install for the basic components.
  # Note: Already installed components should remain unchanged.
  if [[ $operating_system == 'Darwin' ]]; then
    if ! grep '/usr/' <(which cmake) >/dev/null; then
      install_osx_dmg cmake http://www.cmake.org/files/v2.8/cmake-2.8.6-Darwin-universal.dmg
    fi
    if ! grep '/usr/' <(which git) >/dev/null; then
      install_osx_dmg git http://git-osx-installer.googlecode.com/files/git-1.7.4.4-i386-leopard.dmg
    fi
    if ! grep '/usr/' <(which hg) >/dev/null; then
      install_osx_dmg hg http://rudix.googlecode.com/files/mercurial-1.7.1-0.dmg
    fi
    if ! grep '/usr/' <(which curl) >/dev/null; then
      echo "curl is expected to be part of mac os..."
      echo "Please fix curl before continuing."
      exit 1
    fi
    if ! grep '/usr/' <(which gcc) >/dev/null; then
      echo "mvstore is contains c++ components and is released as source code that requires gcc..."
      echo "Please install Xcode (http://developer.apple.com/xcode/) before continuing."
      exit 1
    fi
  else
    if ! grep '/usr/' <(which apt-get) >/dev/null; then
      # With YUM...
      if ! grep -i 'fedora' <(cat /etc/*-release) >/dev/null; then
        sudo rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-4.noarch.rpm
      fi
      sudo yum install ${dependencies_pkg_yum[@]} 
    else
      # With aptitude...
      sudo apt-get update
      sudo apt-get install ${dependencies_pkg_apt[@]}
    fi
  fi

  # Control the node.js version we install.
  preferred_nodejs_version=0.4.7
  if [[ ! `node -v` == 'v'$preferred_nodejs_version ]]; then
    curl -o node-v$preferred_nodejs_version.tar.gz http://nodejs.org/dist/node-v$preferred_nodejs_version.tar.gz
    tar -xvpzf node-v$preferred_nodejs_version.tar.gz
    rm node-v$preferred_nodejs_version.tar.gz
    pushd node-v$preferred_nodejs_version
    ./configure
    make
    sudo make install
    popd
  fi
else
  echo "   no missing dependency"
fi

#
# Configure git.
#
if ! grep 'user.email' <(git config --global -l) >/dev/null; then
  echo ""
  read -p "   configuring git user.email: "
  if [ -z "$REPLY" ]; then
    echo -e "      skipped"
  else
    git config --global user.email "$REPLY"
    read -p "   configuring git user.name: "
    if [ -z "$REPLY" ]; then
      echo -e "      skipped"
    else
      git config --global user.name "$REPLY"
    fi
  fi
fi

#
# Setup ssh-agent, to avoid multiple logins when fetching all the git projects.
#
echo -e "   configuring ssh-agent to facilitate git logins"
if ! grep '/usr/bin' <(ps aux | grep 'ssh-agent') >/dev/null; then
  echo -e "   - starting ssh-agent"
  /usr/bin/ssh-agent
else
  echo -e "   - ssh-agent is already running"
fi
pushd ~/.ssh
ssh_keys=`find . -regex .*id_.* | grep -v .pub`
for iK in ${ssh_keys[@]}; do
  ssh_pub=`head -c 50 $iK.pub`
  if ! grep "$ssh_pub" <(ssh-add -L) >/dev/null; then 
    read -p "   - ssh-add $iK? [Y/n]"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      echo "     user skipped ssh-add $iK"
    else
      ssh-add $iK
    fi
  fi
done
popd

#
# Clone all the github projects.
#
mvstore_projects=(kernel server nodejs doc cloudfoundry tests_kernel setup)
echo -e "\n3. Cloning the mvStore projects:\n   ${mvstore_projects[@]}\n"
sleep 3
for iP in ${mvstore_projects[@]}; do
  if [ -d "$iP" ]; then
    echo "   project $iP already cloned"
  else
    git clone git@github.com:mvStore/$iP.git
  fi
done

#
# Fetch protobuf from google, build it and set it up.
#
echo -e "\n4. Fetching protobuf-2.3.0\n"
sleep 3 
if [ -d "protobuf" ]; then
  echo -e "   directory 'protobuf' already present in\n   $PWD"
  sleep 1
else
  curl -o protobuf-2.3.0.tar.gz http://protobuf.googlecode.com/files/protobuf-2.3.0.tar.gz
  tar -xvpzf protobuf-2.3.0.tar.gz
  rm protobuf-2.3.0.tar.gz
  mv protobuf-2.3.0 protobuf
  pushd protobuf
  ./configure
  make
  echo -e "   installing protobuf..."
  sudo make install
  popd
fi

#
# Fetch protobuf-for-node (using mercurial), build it and set it up.
#
echo -e "\n5. Fetching protobuf-for-node\n"
sleep 3 
if [ -d "protobuf-for-node" ]; then
  echo -e "   directory 'protobuf-for-node' already present in \n   $PWD"
  sleep 1
else
  hg clone http://code.google.com/p/protobuf-for-node/
  pushd protobuf-for-node
  pushd example
  protoc --cpp_out=. protoservice.proto
  popd
  NODE_PATH=/usr/local/bin/node PREFIX_NODE=/usr/local PROTOBUF=../protobuf node-waf configure clean build
  popd
fi

#
# Build mvStore kernel.
#
echo -e "\n6. Building mvStore...\n"
sleep 3 
mkdir kernel/build
pushd kernel/build 
cmake ..
make
popd

#
# Build mvStore server.
#
mkdir server/build
pushd server/build
cmake ..
make
popd

#
# Setup nodejs/mvstore-client.
#
pushd nodejs/mvstore-client
mkdir node_modules
pushd node_modules
ln -s ../../../protobuf-for-node/build/default protobuf-for-node
popd
popd

# TODO: ask if user wants to run tests
# TODO: ask if user wants to start mvserver

