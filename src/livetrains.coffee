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

check_train = (train, time) ->
    if (train.start > train.end) or (train.start > time) or (train.end < time)
        return false
    else
        return true

get_train_position = (train, feature, time) ->
    distance = feature.distance * (time - train.start) / (train.end - train.start)

    i = 0
    total = 0

    for seg_distance in feature.geometries[2].distances
        total = total + seg_distance
        i = i + 1

        if (total > distance)
            break

    return feature.geometries[2].coordinates[i]

calculate_trains = (feature, time) ->
    interesting_trains = [[train, get_train_position(train, feature, time)] for train in feature.timings.reverse when check_train(train, time)]
    return interesting_trains

$ ->
    map = create_map()
    $.getJSON('mrts.json',
        (data) ->
            geojsonlayer = new L.GeoJSON(data)
            map.addLayer(geojsonlayer)

            time = 14400
            markers = { }

            newMarkerIconClass = L.Icon.extend({iconUrl: "img/new-marker.png",});
            newMarkerIcon = new newMarkerIconClass();

            doeet = ->
                trains = []
                for feature in data.features
                    trains.push(train) for train in calculate_trains(feature, time) when train.length != 0
                time += 100

                for train in trains
                    if not markers[train[0][0].trip_id]
                        markers[train[0][0].trip_id] = new L.Marker(new L.LatLng(0, 0), icon:newMarkerIcon)
                        map.addLayer(markers[train[0][0].trip_id])

                    markers[train[0][0].trip_id].setLatLng(new L.LatLng(train[0][1][1], train[0][1][0]))

                if (time < 86400)
                    window.setTimeout(doeet, 300)

            window.setTimeout(doeet, 300)

            return true
    )
