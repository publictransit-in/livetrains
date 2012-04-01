create_map = ->
    map = new L.Map('map')
    nexrad = new L.TileLayer("http://{s}.mqcdn.com/tiles/1.0.0/osm/{z}/{x}/{y}.png", {
        subdomains: ['otile1','otile2','otile3','otile4'],
        maxZoom: 18
    })
    chennai = new L.LatLng(13, 80)
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

            time = 15300
            marker = new L.Marker(new L.LatLng(0, 0))
            map.addLayer(marker)

            doeet = ->
                trains = []
                for feature in data.features
                    trains.push(train) for train in calculate_trains(feature, time) when train.length != 0
                time += 10

                marker.setLatLng(new L.LatLng(trains[0][0][1][1], trains[0][0][1][0]))
                marker.bindPopup("And you never will!").openPopup()
                window.setTimeout(doeet, 300)

            window.setTimeout(doeet, 300)

            #console.log(trains)
            
            return true
    )
