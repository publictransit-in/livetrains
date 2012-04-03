# Draw the initial map
create_map = ->
    map = new L.Map('map')
    nexrad = new L.TileLayer("http://{s}.mqcdn.com/tiles/1.0.0/osm/{z}/{x}/{y}.png", {
        subdomains: ['otile1','otile2','otile3','otile4'],
        maxZoom: 18
    })
    chennai = new L.LatLng(13.0226188, 80.2603651)
    map.setView(chennai, 12)
    map.addLayer(nexrad)
    return map

# See if the given segment (train) encompasses the current time
check_train = (train, time) ->
    if train.start > time
        return -1
    else if train.end < time
        return 1
    else
        return 0

# Find train(s) running between a station pair at the given time
# Uses a binary search since there are a lot of segments to search through and
# we sort them in preprocessing
find_trains = (timings, time, begin, end) ->
    if begin > end
        return []

    i = Math.floor((end + begin) / 2)
    ret = check_train(timings[i], time)

    if begin is end
        if ret is 0
            return [ timings[i] ]
        else
            return []

    if ret is -1
        return find_trains(timings, time, begin, i - 1)
    else if ret is 1
        return find_trains(timings, time, i + 1, end)
    else
        # found one, let's go back and find the first
        i = i - 1 while check_train(timings[i], time) is 0 and i > begin

        # found the first match ...
        if i isnt begin or check_train(timings[i], time)
            i = i + 1

        first = i

        # ... now lets find the last
        i = i + 1 while check_train(timings[i], time) is 0 and i < end

        # found the last
        if i isnt end or check_train(timings[i], time)
            i = i - 1

        last = i

        return timings[first..last]

PI = 3.141592653589793

# Convert from degrees to radians
toRad = (deg) ->
    return deg * PI / 180;

# Convert from radians to degrees
toDeg = (rad) ->
    return rad * 180 / PI

# Given a line segment and distance along it, returns the point at that
# distance when travelled along the line. The first attempt that this will be
# using approximations along a sphere.
#
# Code is taken from: http://www.movable-type.co.uk/scripts/latlong.html
#
# If all this math ends up slowing things down, we should drop down to the
# simpler rectilinear form for interpolation
find_position = (begin, end, distance) ->
    lat1 = toRad(begin[1])
    lon1 = toRad(begin[0])
    lat2 = toRad(end[1])
    lon2 = toRad(end[0])
    dLat = toRad(end[1] - begin[1])
    dLon = toRad(end[0] - begin[0])
    R = 6371000
    d = distance

    y = Math.sin(dLon) * Math.cos(lat2);
    x = Math.cos(lat1)*Math.sin(lat2) -
        Math.sin(lat1)*Math.cos(lat2)*Math.cos(dLon);
    brng = Math.atan2(y, x)

    lat = Math.asin( Math.sin(lat1)*Math.cos(d/R) +
            Math.cos(lat1)*Math.sin(d/R)*Math.cos(brng) );
    lon = lon1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*Math.cos(lat1),
            Math.cos(d/R)-Math.sin(lat1)*Math.sin(lat2));

    return [toDeg(lon), toDeg(lat)]

# Given a station pair and line segments making up the route (feature), and the
# current time, returns a position on the given segment (train)
get_train_position = (train, feature, time) ->
    distance = feature.distance * (time - train.start) / (train.end - train.start)

    i = 0
    total = 0
    rem = 0

    for seg_distance in feature.geometries[2].distances
        total = total + seg_distance
        i = i + 1

        if (total > distance)
            rem = distance - (total - seg_distance)
            break

    return find_position(feature.geometries[2].coordinates[i-1],
                         feature.geometries[2].coordinates[i],
                         rem)

# Iterates the list of station paris (features) and returns and array of ones
# between which there exists a current train and the coordinates at which to
# find the train.
calculate_trains = (feature, time) ->
    # FIXME: Forward going timings seem to be broken (start > end)
    interesting_trains = [[train, get_train_position(train, feature, time)] for train in find_trains(feature.timings.reverse, time, 0, feature.timings.reverse.length)]
    return interesting_trains

$ ->
    map = create_map()
    $.getJSON('mrts.json',
        (data) ->
            REFRESH_RATE = 5 # Hz

            geojsonlayer = new L.GeoJSON(data)
            map.addLayer(geojsonlayer)

            # FIXME: Just for testing. First train is a 4:15am
            time = 15300
            markers = [ ]

            # Distinguish trains by a different marker
            newMarkerIconClass = L.Icon.extend({
                                        iconUrl: "img/choo-choo.png",
                                        iconSize: new L.Point(29, 41),
                                });
            newMarkerIcon = new newMarkerIconClass();

            doeet = ->
                trains = []

                # clear out all markers before we draw them afresh
                # XXX: how do we clean out markers that are no longer relevant?
                for dontcare, marker of markers
                    map.removeLayer(marker)

                # find what segments have a train at the moment
                for feature in data.features
                    trains.push(train) for train in calculate_trains(feature, time) when train.length != 0
                time += 1 / REFRESH_RATE

                for train in trains
                    # We create a marker for each trip_id
                    if not markers[train[0][0].trip_id]
                        markers[train[0][0].trip_id] = new L.Marker(new L.LatLng(0, 0), icon:newMarkerIcon)

                    # Now display this train
                    map.addLayer(markers[train[0][0].trip_id])
                    markers[train[0][0].trip_id].setLatLng(new L.LatLng(train[0][1][1], train[0][1][0]))

                # We can call it a day :}
                if (time < 86400)
                    window.setTimeout(doeet, 1000 / REFRESH_RATE)

            window.setTimeout(doeet, 1000 / REFRESH_RATE)

            return true
    )
