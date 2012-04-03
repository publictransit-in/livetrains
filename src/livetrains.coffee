# Draw the initial map
create_map = ->
    # Performance hack, cuts about 10% of our CPU usage
    L.Browser.webkit3d = false

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
get_train_position = (train, feature, time, forward) ->
    distance = feature.distance * (time - train.start) / (train.end - train.start)

    if not feature.geometries[2].distances_rev
        feature.geometries[2].distances_rev = []
        len = feature.geometries[2].distances.length - 1

        for i in [0..len]
            feature.geometries[2].distances_rev[i] = feature.geometries[2].distances[len - i]

    if (forward)
        distances = feature.geometries[2].distances
    else
        distances = feature.geometries[2].distances_rev

    i = 0
    total = 0
    rem = 0

    for seg_distance in distances
        total = total + seg_distance
        i = i + 1

        if (total > distance)
            rem = distance - (total - seg_distance)
            break

    # Note that the loop above iterates over distances. distance[i] is the
    # distance between coordinate[i-1] and cooridinate[i] (since distance[0] is
    # the distance between coordinate[0] and coordinate[1]. Remember this if
    # you're wondering why tha array index math below is the way it is.
    if (forward)
        return find_position(feature.geometries[2].coordinates[i - 1],
                             feature.geometries[2].coordinates[i],
                             rem)
    else
        return find_position(feature.geometries[2].coordinates[distances.length - i + 1],
                             feature.geometries[2].coordinates[distances.length - i],
                             rem)

# Iterates the list of station paris (features) and returns and array of ones
# between which there exists a current train and the coordinates at which to
# find the train.
calculate_trains = (feature, time) ->
    # FIXME: Reverse going timings seem to be broken (start > end)
    interesting_trains = [[train, get_train_position(train, feature, time, true)] for train in find_trains(feature.timings.forward, time, 0, feature.timings.forward.length)]
    temp = [[train, get_train_position(train, feature, time, false)] for train in find_trains(feature.timings.reverse, time, 0, feature.timings.reverse.length)]
    interesting_trains.push(train) for train in temp
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
                # The 'active' property is set to 2 on every addLayer call and
                # decremented for every removeLayer. If the value drops to
                # zero, this means we no longer need to update it and can get
                # rid of it
                for key, marker of markers
                    map.removeLayer(marker.marker)
                    marker.active = marker.active - 1

                    if marker.active is 0
                        delete markers[key]

                # find what segments have a train at the moment
                for feature in data.features
                    trains.push(train) for train in calculate_trains(feature, time) when train.length != 0
                time += 1 / REFRESH_RATE

                for train in trains
                    # We create a marker for each trip_id
                    if not markers[train[0][0].trip_id]
                        marker = new L.Marker(new L.LatLng(0, 0), icon:newMarkerIcon)
                        # See note above for a description of the 'active' property
                        markers[train[0][0].trip_id] = { marker: marker, active: 2 }

                    # Now display this train
                    map.addLayer(markers[train[0][0].trip_id].marker)
                    markers[train[0][0].trip_id].marker.setLatLng(new L.LatLng(train[0][1][1], train[0][1][0]))
                    markers[train[0][0].trip_id].active = 2

                # We can call it a day :}
                if (time < 86400)
                    window.setTimeout(doeet, 1000 / REFRESH_RATE)

            window.setTimeout(doeet, 1000 / REFRESH_RATE)

            return true
    )
