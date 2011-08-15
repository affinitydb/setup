#!/bin/bash

# Greetings.
echo "Welcome to mvStore!"
echo ""
echo "This setup script will perform the following steps:"
echo ""
echo "   1. create a mvStore directory that will contain the installed components"
echo "   2. check external dependencies such as cmake, node.js etc. (install them if not present)"
echo "   3. fetch protobuf-2.3.0 from google and build it"
echo "   4. fetch protobuf_for_node and build it"
echo "   5. clone the mvStore projects from github and build them"
echo "   6. (optional) start the mvStore server"
echo ""
read -p "Ready to start? [Y/n]"
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "   cancelling setup upon user's request"
  exit 1
fi

# Create a mvStore directory to contain everything.
echo -e "\n1. Creating mvStore...\n"
mkdir -p mvStore
cd mvStore
echo "   $PWD"
sleep 1

# Check dependencies and install missing elements.
dependencies_exe=(cmake curl git node)
dependencies_pkg=(cmake curl git-core libssl-dev)
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

# Fetch protobuf from google, build it and set it up.
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

# TODO: build protobuf_for_node and connect it to nodejs

# Clone all the github projects.
# TODO: start and setup ssh-agent to avoid multiple git logins
#   echo http://help.github.com/ssh-key-passphrases/
#   echo http://mah.everybody.org/docs/ssh#run-ssh-agent
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

# Build mvStore kernel.
echo -e "\n   Building mvStore kernel...\n"
sleep 1
mkdir kernel/build
pushd kernel/build 
cmake ..
make
popd

# Build mvStore server.
echo -e "\n   Building mvStore server...\n"
sleep 1
mkdir server/build
pushd server/build
cmake ..
make
popd

# TODO: ask if user wants to run tests
# TODO: ask if user wants to start mvserver
