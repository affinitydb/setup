#!/bin/bash
# Copyright (c) 2004-2013 GoPivotal, Inc. All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,  WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
operating_system=`uname -s`

#
# Greetings.
#
echo "Welcome to Affinity!"
echo ""
echo "Prior to running this setup, please make sure to:"
echo ""
echo "   - have a personal github account"
echo "   - be a sudoer"
echo ""  
echo "This setup script will perform the following steps:"
echo ""
echo "   1. create an Affinity directory that will contain the installed components"
echo "   2. check external dependencies and components such as cmake, curl,"
echo "      node.js etc. (install them if not present)"
echo "   3. clone the Affinity projects from github"
echo "   4. fetch protobuf from google and build it"
echo "   5. fetch protobuf-for-node and build it"
echo "   6. build Affinity"
echo ""
echo "OS: $operating_system"
read -p "Ready to start? [Y/n]"
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "   cancelling setup upon user's request"
  exit 1
fi

#
# Create a Affinity directory to contain everything.
#
echo -e "\n1. Creating Affinity...\n"
mkdir -p Affinity
cd Affinity
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
dependencies_exe=(cmake curl git node gcc)
dependencies_pkg_apt=(cmake curl git-core libssl-dev)
dependencies_pkg_yum=(cmake curl git-core openssl-devel gcc-c++)
echo -e "\n2. Checking dependencies: ${dependencies_exe[@]}\n"
sleep 1
dependencies_doinstall=0
for iD in ${dependencies_exe[@]}; do
  case $(which $iD 2>/dev/null) in
    /opt/*) true ;;
    /usr/*) true ;;
    *)
      echo "   * $iD is not present - will install"
      dependencies_doinstall=1
      ;;
  esac
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
    if ! grep '/usr/' <(which curl 2>/dev/null) >/dev/null; then
      echo "curl is expected to be part of mac os..."
      echo "Please fix curl before continuing."
      exit 1
    fi
    if ! grep '/usr/' <(which gcc 2>/dev/null) >/dev/null; then
      echo "Affinity contains c++ components and is released as source code that requires gcc..."
      echo "Please install Xcode (http://developer.apple.com/xcode/) before continuing."
      exit 1
    fi
    if ! grep '/usr/' <(which cmake 2>/dev/null) >/dev/null; then
      install_osx_dmg cmake http://www.cmake.org/files/v2.8/cmake-2.8.10.1-Darwin-universal.dmg
    fi
    if ! grep '/usr/' <(which git 2>/dev/null) >/dev/null; then
      install_osx_dmg git http://git-osx-installer.googlecode.com/files/git-1.7.4.4-i386-leopard.dmg
    fi
  else
    if ! grep '/usr/' <(which apt-get 2>/dev/null) >/dev/null; then
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
  # Note: the original version of protobuf_for_node requires node-waf, and an older version of v8.
  # Note: chrisdew's version, installed by npm (https://github.com/chrisdew/protobuf), works at least until 0.8.5.
  preferred_nodejs_version=0.8.5
  if [[ ! `node -v` == 'v'$preferred_nodejs_version ]]; then
    curl -o node-v$preferred_nodejs_version.tar.gz http://nodejs.org/dist/v$preferred_nodejs_version/node-v$preferred_nodejs_version.tar.gz
    tar -xvpzf node-v$preferred_nodejs_version.tar.gz
    rm node-v$preferred_nodejs_version.tar.gz
    pushd node-v$preferred_nodejs_version
    ./configure
    make
    bogus=`sudo make install`
    popd
  fi
else
  echo "   no missing dependency"
fi

#
# Configure git.
#
if ! grep 'user.email' <(git config --global -l 2>/dev/null) >/dev/null; then
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
# Note: This will no longer be required when projects become public.
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
affinity_projects=(kernel server nodejs python ruby java doc tests_kernel setup)
echo -e "\n3. Cloning the Affinity projects:\n   ${affinity_projects[@]}\n"
sleep 3
for iP in ${affinity_projects[@]}; do
  if [ -d "$iP" ]; then
    echo "   project $iP already cloned"
  else
    git clone git@github.com:affinitydb/$iP.git
  fi
done

#
# Fetch protobuf from google, build it and set it up.
#
echo -e "\n4. Fetching protobuf\n"
sleep 3 
if [ -d "protobuf" ]; then
  echo -e "   directory 'protobuf' already present in\n   $PWD"
  sleep 1
else
  preferred_protobuf_version=2.4.1
  curl -o protobuf-$preferred_protobuf_version.tar.gz http://protobuf.googlecode.com/files/protobuf-$preferred_protobuf_version.tar.gz
  tar -xvpzf protobuf-$preferred_protobuf_version.tar.gz
  rm protobuf-$preferred_protobuf_version.tar.gz
  mv protobuf-$preferred_protobuf_version protobuf
  pushd protobuf
  ./configure
  make
  echo -e "   installing protobuf..."
  bogus=`sudo make install`
  popd
fi

#
# Build Affinity kernel.
# Note: We set CC and CXX for cmake to use GNU (as opposed to clang) on the Mac.
#
echo -e "\n6. Building Affinity...\n"
sleep 3 
mkdir kernel/build
pushd kernel/build 
CC=/usr/bin/gcc CXX=/usr/bin/g++ cmake ..
make
popd

#
# Build Affinity server.
# Note: We set CC and CXX for cmake to use GNU (as opposed to clang) on the Mac.
#
mkdir server/build
pushd server/build
CC=/usr/bin/gcc CXX=/usr/bin/g++ cmake ..
make
popd

#
# Setup nodejs/affinity-client.
#
pushd nodejs/affinity-client
mkdir node_modules
npm install protobuf
popd

echo ""
echo "Affinity is installed!"
echo "To run the server:"
echo ""
echo "  cd Affinity/server"
echo "  bin/affinityd -d src/www"
echo ""
echo "... then visit http://localhost:4560 in a browser."
