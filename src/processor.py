#!/usr/bin/env python
import sys
import math

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

# From http://www.platoscave.net/blog/2009/oct/5/calculate-distance-latitude-longitude-python/
# FIXME: verify this
def haversine_distance(origin, destination):
    lon1, lat1 = origin
    lon2, lat2 = destination
    radius = 6371000 # m

    dlat = math.radians(lat2-lat1)
    dlon = math.radians(lon2-lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) \
        * math.cos(math.radians(lat2)) * math.sin(dlon/2) * math.sin(dlon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    d = radius * c

    return d

def calc_distance(current_path):
    if len(current_path) < 2:
        return 0

    distance = 0

    for i in range(1, len(current_path)):
        distance += haversine_distance(current_path[i-1], current_path[i])

    return distance

def insert_geometry_distances(geometries):
    geometries[2].extra['distances'] = []

    if len(geometries[2].coordinates) < 2:
        return

    for i in range(1, len(geometries[2].coordinates)):
        geometries[2].extra['distances'].append(haversine_distance(geometries[2].coordinates[i-1], geometries[2].coordinates[i]))

for i in xrange(track_path.GetPointCount()):
    dot = track_path.GetPoint_2D(i)
    current_path.append(dot)
    if dot in stations:
        this_station = stations[dot]
        if last_station:
            if current_path[0] != last_station.coordinates:
                current_path.insert(0, last_station.coordinates)

            segment = geojson.GeometryCollection()
            segment.geometries.append(last_station)
            segment.geometries.append(this_station)
            segment.geometries.append(geojson.LineString(current_path))
            segment.extra['begin'] = last_station.extra['name']
            segment.extra['end'] = this_station.extra['name']
            segment.extra['distance'] = calc_distance(current_path)

            insert_geometry_distances(segment.geometries)

            timings = {
                    'forward': [],
                    'reverse': []
                    }
            for trip in forward:
                start = get_stop_time(trip, last_station.extra['name'])
                end = get_stop_time(trip, this_station.extra['name'])
                timings['forward'].append({
                                        'trip_id': trip.trip_id,
                                        'start': start.arrival_secs,
                                        'end': end.arrival_secs
                                        })
            timings['forward'].sort(key=lambda timing: timing['start'])

            for trip in reverse:
                start = get_stop_time(trip, last_station.extra['name'])
                end = get_stop_time(trip, this_station.extra['name'])
                timings['reverse'].append({
                                        'trip_id': trip.trip_id,
                                        'start': start.arrival_secs,
                                        'end': end.arrival_secs
                                        })
            timings['reverse'].sort(key=lambda timing: timing['start'])

            segment.extra['timings'] = timings

            segments.append(segment)
            current_path = []
        last_station = this_station

features = geojson.FeatureCollection(segments)
output = open(output_path, 'w')
output.write(geojson.dumps(features))
