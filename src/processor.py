#!/usr/bin/env python
import sys

import geojson
import transitfeed
from osgeo import ogr


def get_stop_time(trip, stop_name):
    for st in trip.GetStopTimes():
        if st.stop.stop_id == stop_name:
            return st

    raise Exception("No stop with name %s found in the trip" % stop_name)

filepath = sys.argv[1]
gtfs_path = sys.argv[2]
route_id = raw_input("Enter route id: ")
output_path = sys.argv[3]

gpx = ogr.Open(filepath)

# Layer containing the station points
points = gpx.GetLayerByName('waypoints')

# Layer containing the path of the railway track
# Assumes there's just one huge LineString in the MultiLineString
# Manually merged in on JOSM or equivalent.
track = gpx.GetLayerByName('tracks')[0]
track_path = track.GetGeometryRef().GetGeometryRef(0)

stations = {}
for p in points:
    location = p.GetGeometryRef()
    station = geojson.Point((location.GetX(), location.GetY()))
    station.extra['name'] = p.GetField(p.GetFieldIndex('name'))
    stations[station.coordinates] = station

schedule = transitfeed.Schedule()
schedule.Load(gtfs_path)

route = schedule.GetRoute(route_id)
# No idea where pattern_id comes from
# Pretty sure they're gonna fuck me over big time someday
# Assume that first key is A -> B and second is B -> A
forward, reverse = route.GetPatternIdTripDict().values()
# Make sure that our assumptions hold
# Better to fail and fix than to fail and get laughed at
assert [t for t in forward if t.direction_id == 1] == []
assert [t for t in reverse if t.direction_id == 0] == []

last_station = None
current_path = []
segments = []

for i in xrange(track_path.GetPointCount()):
    dot = track_path.GetPoint_2D(i)
    current_path.append(dot)
    if dot in stations:
        this_station = stations[dot]
        if last_station:
            current_path.insert(0, last_station.coordinates)
            segment = geojson.GeometryCollection()
            segment.geometries.append(last_station)
            segment.geometries.append(this_station)
            segment.geometries.append(geojson.LineString(current_path))
            segment.extra['begin'] = last_station.extra['name']
            segment.extra['end'] = this_station.extra['name']

            timings = {
                    'forward': [],
                    'reverse': []
                    }
            for trip in forward:
                start = get_stop_time(trip, last_station.extra['name'])
                end = get_stop_time(trip, this_station.extra['name'])
                timings['forward'].append((start.arrival_secs, end.arrival_secs))

            for trip in reverse:
                start = get_stop_time(trip, last_station.extra['name'])
                end = get_stop_time(trip, this_station.extra['name'])
                timings['reverse'].append((start.arrival_secs, end.arrival_secs))

            segment.extra['timings'] = timings

            segments.append(segment)
            current_path = []
        last_station = this_station

features = geojson.FeatureCollection(segments)
output = open(output_path, 'w')
output.write(geojson.dumps(features))
