Read Me
=======

Pre-requisites
--------------
* [Coffeescript](http://jashkenas.github.com/coffee-script/)
* [SASS](http://sass-lang.com/)
* [GeoJSON Python Library](http://pypi.python.org/pypi/geojson/1.0)
* [Transitfeed Python Library](http://code.google.com/p/googletransitdatafeed/)
* [GDAL Python library](http://pypi.python.org/pypi/GDAL/)

Optional requirements
---------------------
* [Python Timezone](http://pypi.python.org/pypi/pytz/)

Install (On Ubuntu)
-------------------
* `sudo apt-get install coffeescript libhaml-ruby1.8 python-pip python-gdal`
* `sudo pip install geojson transitfeed pytz`
* `make`

Testing
-------
* Point your browser to ./public/demo.html

Deployment
----------
* Copy/Symlink ./public directory under your web root folder(/var/www)
