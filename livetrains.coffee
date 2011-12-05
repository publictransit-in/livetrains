create_map = ->
    map = new L.Map('map')
    nexrad = new L.TileLayer.WMS("http://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r.cgi", {
    layers: 'nexrad-n0r-900913',
    format: 'image/png',
    attribution: "Weather data © 2011 IEM Nexrad"
    })
    chennai = new L.LatLng(13, 80)
    map.setView(chennai, 12)
    map.addLayer(nexrad)
    return map

calculate_trains = (segment, time) ->


$ ->
    map = create_map()
    $.getJSON('mrts.json',
        (data) ->
            geojsonlayer = new L.GeoJSON(data)
            map.addLayer(geojsonlayer)

            
            return true
    )
