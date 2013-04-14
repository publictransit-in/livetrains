Read Me
=======

Pre-requisites
--------------
* [Coffeescript](http://jashkenas.github.com/coffee-script/)
* [GeoJSON Python Library](http://pypi.python.org/pypi/geojson/1.0)
* [Transitfeed Python Library](http://code.google.com/p/googletransitdatafeed/)
* [GDAL Python library](http://pypi.python.org/pypi/GDAL/)

Optional requirements
---------------------
* [Python Timezone](http://pypi.python.org/pypi/pytz/)

Install (On Ubuntu)
-------------------
* `sudo apt-get install make coffeescript python-pip python-gdal`
* `sudo pip install geojson transitfeed pytz`
* `make`

Install (On Ubuntu with virtualenv)
-----------------------------------
* `sudo apt-get install make coffeescript python-pip libgdal1-dev`
* `sudo pip install virtualenv`
* `virtualenv venv`
* `. venv/bin/activate`
* `pip install -r requirements.txt`
* `sudo wget http://svn.osgeo.org/gdal/branches/1.7/gdal/ogr/swq.h -o /usr/include/swq.h`
* `pip install --no-install GDAL==1.7.0`
* `cd venv/build/GDAL && python setup.py build_ext --include-dirs=/usr/include/gdal`
* `pip install --no-download GDAL`

Testing
-------
* `make test`
* Point your browser to ./public/demo.html

Deployment
----------
* Copy/Symlink ./public directory under your web root folder(/var/www)
