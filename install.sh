#!/bin/bash
# intended for Ubuntu 14.04, see
# http://switch2osm.org/serving-tiles/manually-building-a-tile-server-14-04/

DATABASE_USER=gisuser
# WARNING: DATABASE_NAME must match mapnik style configuration
DATABASE_NAME=osm
DATA_URL=http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf
MD5SUM_URL=http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf.md5
DATA_FILENAME=berlin-latest.osm.pbf


### DATABASE ###

# install PostGIS, osm2pgsql
sudo apt-get install postgresql postgresql-contrib postgis postgresql-9.3-postgis-2.1

# TODO configure Postgres (performance tuning)
# configure PostGIS
sudo -u postgres createuser $DATABASE_USER
sudo -u postgres createdb --encoding=UTF8 --owner=$DATABASE_USER $DATABASE_NAME
sudo -u postgres psql -d $DATABASE_NAME -c "CREATE EXTENSION postgis;"
# 3 lines below should be similar to CREATE EXTENSION postgis
#sudo -u postgres psql -d $DATABASE_NAME -f /usr/share/postgresql/9.3/contrib/postgis-2.1/postgis.sql
#sudo -u postgres psql -d $DATABASE_NAME -f /usr/share/postgresql/9.3/contrib/postgis-2.1/spatial_ref_sys.sql
#sudo -u postgres psql -d $DATABASE_NAME -f /usr/share/postgresql/9.3/contrib/postgis-2.1/postgis_comments.sql
sudo -u postgres psql -d $DATABASE_NAME -c "CREATE EXTENSION hstore;"
sudo -u postgres psql -d $DATABASE_NAME -c "GRANT SELECT ON spatial_ref_sys TO PUBLIC;"
sudo -u postgres psql -d $DATABASE_NAME -c "GRANT ALL ON geometry_columns TO $DATABASE_USER;"

# test PostGIS (can insert points, spatial query)
psql --username=$DATABASE_USER --dbname=$DATABASE_NAME --command="\d" # should list the tables geometry_columns and spatial_ref_sys
# TODO test functionality:
#select postgis_full_version(); 
#select ST_Point(1, 2) AS MyFirstPoint; 
#select ST_SetSRID(ST_Point(-77.036548, 38.895108),4326); -- using WGS 84 


### DATA IMPORT ###

# install osm2pgsql 
sudo apt-get install osm2pgsql
# TODO test osm2pgsql (binary exists, help/version info shows)

# download berlin.pbf, import (can query for city label)
curl -o /tmp/$DATA_FILENAME.md5 $MD5SUM_URL
curl -o /tmp/$DATA_FILENAME $DATA_URL
# TODO fail if m5sum is wrong
(cd /tmp && md5sum -c $DATA_FILENAME.md5)
# NOTE: --flat-nodes does not work well with small data, use it for planet.osm
osm2pgsql --create --slim --cache 2048 --username $DATABASE_USER --database $DATABASE_NAME --prefix planet --hstore /tmp/$DATA_FILENAME


### VECTOR TILES ###
# for existing implementations, see
# https://github.com/mapbox/vector-tile-spec/wiki/Implementations

# install Mapnik
#sudo apt-get install -y python-software-properties
#sudo add-apt-repository -y ppa:developmentseed/mapbox
#sudo apt-get update
#sudo apt-get install -y libmapnik
sudo apt-get install -y libmapnik2.2
sudo apt-get install -y libmapnik-dev mapnik-utils python-mapnik

# install mapnik-vector-tile from source
sudo apt-get install -y libprotobuf8 libprotobuf-dev protobuf-compiler
curl -o mapnik-vector-tile.tar.gz https://codeload.github.com/mapbox/mapnik-vector-tile/tar.gz/master
tar xzf mapnik-vector-tile.tar.gz
rm mapnik-vector-tile.tar.gz
cd mapnik-vector-tile-master/
make
export MAPNIK_VECTOR=$(pwd)/src
cd

# install vector-tiles-producer from source
sudo apt-get install -y build-essential
curl -o vector-tiles-producer.tar.gz https://codeload.github.com/osmbike/vector-tiles-producer/tar.gz/master
tar xzf vector-tiles-producer.tar.gz
rm vector-tiles-producer.tar.gz
cd vector-tiles-producer-master/
make create
cd

# install osmbright style
curl -o osm-bright.tar.gz https://codeload.github.com/mapbox/osm-bright/tar.gz/master
tar xzf osm-bright.tar.gz
rm osm-bright.tar.gz
cd osm-bright-master/
# get coastline shapefiles
mkdir shp/
cd shp/
sudo apt-get install -y unzip
curl -O http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
curl -O http://data.openstreetmapdata.com/land-polygons-split-3857.zip
# curl -O http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip
unzip simplified-land-polygons-complete-3857.zip
unzip land-polygons-split-3857.zip
cd simplified-land-polygons-complete-3857/
shapeindex simplified_land_polygons.shp
cd ..
cd land-polygons-split-3857/
shapeindex land_polygons.shp
cd ..
# TODO rm .zip
# convert Tilemill project to Mapnik style
cd ~/Documents/MapBox/project/OSMBright/
sudo apt-get install -y node-carto
carto project.mml > OSMBright.xml
MAPNIK_STYLE=~/Documents/MapBox/project/OSMBright/OSMBright.xml
cd
# install fonts
sudo apt-get install -y ttf-dejavu fonts-droid ttf-unifont fonts-sipa-arundina fonts-sil-padauk fonts-khmeros \
	ttf-indic-fonts-core ttf-tamil-fonts ttf-kannada-fonts

# create vector tiles from Mapnik stylesheet
# z x y is the tile coordinate from which subtiles are created,
# use 0 0 0 for whole world
# minz maxz is min, max zoom
# TODO
#./create_tiles --compress minz maxz x y path/to/stylesheet
./create_tiles --compress 10 13 13.3888599 52.5170365 $MAPNIK_STYLE
# TODO test vector tile (file exists, contains city label)


### DATA UPDATES ###
# TODO minutely updates (postgis, vector tiles)
