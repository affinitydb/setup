#!/bin/bash

#
# Greetings.
#
echo "Welcome to mvStore!"
echo ""
echo "This setup script will perform the following steps:"
echo ""
echo "   1. create a mvStore directory that will contain the installed components"
echo "   2. check external dependencies such as cmake, curl, node.js etc."
echo "      (install them if not present)"
echo "   3. fetch protobuf-2.3.0 from google and build it"
echo "   4. fetch protobuf-for-node and build it"
echo "   5. clone the mvStore projects from github and build them"
echo "   6. (optional) start the mvStore server"
echo ""
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
dependencies_exe=(cmake curl git hg node)
dependencies_pkg=(cmake curl git-core mercurial libssl-dev)
echo -e "\n2. Checking dependencies: ${dependencies_exe[@]}\n"
sleep 1
dependencies_doinstall=0
for iD in ${dependencies_exe[@]}; do
  if ! grep '/usr/' <(whereis $iD) >/dev/null; then
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
  sudo apt-get update
  sudo apt-get install ${dependencies_pkg[@]}

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
# Fetch protobuf from google, build it and set it up.
#
echo -e "\n3. Fetching protobuf-2.3.0\n"
sleep 1
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
  popd
fi

#
# Fetch protobuf-for-node (using mercurial), build it and set it up.
#
echo -e "\n4. Fetching protobuf-for-node\n"
sleep 1
if [ -d "protobuf-for-node" ]; then
  echo -e "   directory 'protobuf-for-node' already present in \n   $PWD"
  sleep 1
else
  hg clone https://code.google.com/p/protobuf-for-node/
  pushd protobuf-for-node
  python ../../setup/tools/adjust_protobuf_for_node_wscript.py wscript
  NODE_PATH=/usr/local/bin/node PREFIX_NODE=/usr/local PROTOBUF=../protobuf node-waf configure clean build
  popd
fi

#
# Setup ssh-agent, to avoid multiple logins when fetching all the git projects.
#
if ! grep '/usr/bin' <(ps aux | grep 'ssh-agent') >/dev/null; then
  echo -e "   starting ssh-agent"
  /usr/bin/ssh-agent
fi
pushd ~/.ssh
ssh_keys=`find -regex .*id_.* | grep -v .pub`
for iK in ${ssh_keys[@]}; do
  ssh_pub=`head -c 50 $iK.pub`
  if ! grep "$ssh_pub" <(ssh-add -L) >/dev/null; then 
    read -p "   ssh-add $iK? [Y/n]"
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      echo "      skipped $iK"
    else
      ssh-add $iK
    fi
  fi
done
popd

#
# Clone all the github projects.
#
mvstore_projects=(kernel server nodejs doc cloudfoundry tests_kernel)
echo -e "\n5. Cloning the mvStore projects:\n   ${mvstore_projects[@]}\n"
sleep 1
for iP in ${mvstore_projects[@]}; do
  if [ -d "$iP" ]; then
    echo "   project $iP already cloned"
  else
    git clone git@github.com:mvStore/$iP.git
  fi
done

#
# Build mvStore kernel.
#
echo -e "\n   Building mvStore kernel...\n"
sleep 1
mkdir kernel/build
pushd kernel/build 
cmake ..
make
popd

#
# Build mvStore server.
#
echo -e "\n   Building mvStore server...\n"
sleep 1
mkdir server/build
pushd server/build
cmake ..
make
popd

# TODO: setup nodejs (mvstore.desc etc.)
# TODO: ask if user wants to run tests
# TODO: ask if user wants to start mvserver
