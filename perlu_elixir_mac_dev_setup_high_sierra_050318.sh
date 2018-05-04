#!/bin/sh

# try to run docker
docker ps  >/dev/null 2>&1

if [ $? != 0 ]
then
	echo ""
	echo "WARNING: Docker must be installed and available before running this install script"
	echo ""
	echo "Please go to:"
	echo "https://store.docker.com/editions/community/docker-ce-desktop-mac"
	echo ""
	echo "Click the \"Get Docker CE for Mac (Stable)\" button"
	echo "    open the .dmg"
	echo "    drag Docker to Applications"
	echo "    eject Docker from devices"
	echo "    open Docker (and wait for Docker installation to finish)"
	echo ""
	echo "After install:"
	echo "    Click the Docker (Whale) icon in the menubar, "
	echo "    go to Preferences -> Advanced and give Docker at least 4GB RAM and 2 CPUs."
	echo "    Run this script again."
	
	echo ""
	echo "NOTE - detailed install notes can be found here:"
	echo "https://github.com/terakeet/perlu_elixir/wiki/Setting-up-Developer-Machines"
	echo ""
	
	exit 1
fi

echo ""
echo "PLEASE NOTE: "
echo "This install script assumes you have GitHub's two-factor authentication enabled!"
echo "(It uses the SSH version of the GitHub git clone operation)"
echo ""

cd ~

# Install Homebrew and Tools
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install redis coreutils automake autoconf openssl libyaml readline libxslt libtool unixodbc git htop wget npm
brew tap caskroom/cask
brew cask install chromedriver

# start redis
brew services start redis

# Install Cassandra
docker run -p 127.0.0.1:9042:9042 -p 127.0.0.1:9160:9160 -e MAX_HEAP_SIZE=1G -e HEAP_NEWSIZE=256M --name cassandra -d cassandra:3.7

# Install Neo4j
mkdir -p ~/docker ~/docker/neo4j-t ~/docker/neo4j-d
docker run --name neo4j_test --volume=$HOME/docker/neo4j-t/data:/data:cached -p 127.0.0.1:8484:7474 -p 127.0.0.1:8687:7687 --env=NEO4J_AUTH=none -d neo4j:3.2.3-enterprise
docker run --name neo4j_dev --volume=$HOME/docker/neo4j-d/data:/data:cached -p 127.0.0.1:7474:7474 -p 127.0.0.1:7687:7687 --env=NEO4J_AUTH=none -d neo4j:3.2.3-enterprise

# install Elastic Search
docker run -p 127.0.0.1:10200:9200 -e ES_JAVA_OPTS="-Xms1g -Xmx1g" -v estest:/usr/share/elasticsearch/data -e "discovery.type=single-node" -e "xpack.security.enabled=false" --name elastic_test -d docker.elastic.co/elasticsearch/elasticsearch:6.0.1
docker network create elastic --driver=bridge 
docker run -p 127.0.0.1:9200:9200 -e ES_JAVA_OPTS="-Xms1g -Xmx1g" -v esdev:/usr/share/elasticsearch/data -e "discovery.type=single-node" -e "xpack.security.enabled=false" --name elasticsearch -d --network elastic docker.elastic.co/elasticsearch/elasticsearch:6.0.1
docker run -p 127.0.0.1:5601:5601 -e ES_JAVA_OPTS="-Xms1g -Xmx1g"  --name kibana_dev -d --network elastic docker.elastic.co/kibana/kibana:6.0.1

# Install Redis LRU
docker run --name perlu_redis_lru -p 127.0.0.1:6378:6379 -d redis:3.2.10 redis-server --save "" --appendonly no --maxmemory 5mb --maxmemory-policy allkeys-lru

# Setup ASDF (Version Manager)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.4.3
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bash_profile
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bash_profile
source ~/.bash_profile
asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install erlang 20.1
asdf install elixir 1.6.0
asdf global erlang 20.1
asdf global elixir 1.6.0

# Setup Cassandra Keyspaces
brew install python
sudo easy_install pip
pip install --user cqlsh
echo "export PATH=./Library/Python/2.7/bin:${PATH}" >> ~/.bash_profile
source ~/.bash_profile
echo "CREATE KEYSPACE fountain WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };" | cqlsh
echo "CREATE  KEYSPACE fountain_test WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };" | cqlsh

# Launch the project
# HTTPS:
# git clone https://github.com/terakeet/perlu_elixir
# SSH:
git@github.com:terakeet/perlu_elixir.git
cd perlu_elixir
mix deps.get
cd apps/web
npm install
cd ../..

# just in case necessary
npm rebuild node-sass

# Initialize Local Stores
echo "Common.Domain.Helpers.standup_repos(true); System.halt()" | iex -S mix phx.server
echo "Common.Stores.Column.CassandraInit.install_tables; System.halt()" | iex -S mix phx.server

# Run the seeds file from a command line
mix run apps/common/priv/repo/seeds.exs

echo ""
echo "**************************************************************"
echo "If the install worked as expected (no fatal errors, etc.),"
echo "you should be now able to go to the perlu_elixir directory:"
echo "$ cd ~/perlu_elixir"
echo ""
echo "...and run this to start the Perlu application:"
echo "$ iex -S mix phx.server"
echo ""
echo "Assuming Perlu is now running, open a browser window and go to:"
echo "http://localhost:4000/"
echo "and you should see Perlu running. (Yay!) Click \"Join\". and you're on your way."
echo "**************************************************************"
echo ""

exit 0
