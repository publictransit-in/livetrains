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
    if (train.start > train.end) or (train.start > time) or (train.end < time)
        return false
    else
        return true

# Given a station pair and line segments making up the route (feature), and the
# current time, returns a position on the given segment (train)
get_train_position = (train, feature, time) ->
    distance = feature.distance * (time - train.start) / (train.end - train.start)

    i = 0
    total = 0

    for seg_distance in feature.geometries[2].distances
        total = total + seg_distance
        i = i + 1

        if (total > distance)
            break

    # FIXME: This places us at the beginning of the line segment that we are
    # contained in. This should be refined to actually interpolate to a
    # coordinate for smooth movements.
    return feature.geometries[2].coordinates[i]

# Iterates the list of station paris (features) and returns and array of ones
# between which there exists a current train
calculate_trains = (feature, time) ->
    # FIXME: Forward going timings seem to be broken (start > end)
    interesting_trains = [[train, get_train_position(train, feature, time)] for train in feature.timings.reverse when check_train(train, time)]
    return interesting_trains

$ ->
    map = create_map()
    $.getJSON('mrts.json',
        (data) ->
            geojsonlayer = new L.GeoJSON(data)
            map.addLayer(geojsonlayer)

            # FIXME: Just for testing. First train is a 4:15am
            time = 15300
            markers = { }

            # Distinguish trains by a different marker
            newMarkerIconClass = L.Icon.extend({iconUrl: "img/new-marker.png",});
            newMarkerIcon = new newMarkerIconClass();

            doeet = ->
                trains = []

                # find what segments have a train at the moment
                for feature in data.features
                    trains.push(train) for train in calculate_trains(feature, time) when train.length != 0
                time += 1

                for train in trains
                    # We create a marker for each trip_id
                    if not markers[train[0][0].trip_id]
                        markers[train[0][0].trip_id] = new L.Marker(new L.LatLng(0, 0), icon:newMarkerIcon)
                        map.addLayer(markers[train[0][0].trip_id])

                    # Now display this train
                    markers[train[0][0].trip_id].setLatLng(new L.LatLng(train[0][1][1], train[0][1][0]))

                # We can call it a day :}
                if (time < 86400)
                    window.setTimeout(doeet, 1000)

            window.setTimeout(doeet, 1000)

            return true
    )
