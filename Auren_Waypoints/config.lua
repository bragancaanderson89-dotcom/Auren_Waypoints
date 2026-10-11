WaypointConfig = {
    command = 'gps3d',
    onlyInVehicles = true,
    renderDistance = 400.0,
    markerDistance = 5000.0,
    markerHeight = 18.0,
    arrivalDistance = 12.0,
    sampleInterval = 90,
    maximumChevrons = 64,
    routeGracePeriod = 650,
    markerInterval = 33,
    maximumLaneOffset = 8.0,
    defaults = {
        road = true, destination = true, color = '#38bdf8', secondaryColor = '#a78bfa',
        style = 'chevron', destinationStyle = 'beacon', quality = 'balanced',
        spacing = 8.0, opacity = 0.82, lift = 0.16, scale = 1.0,
        width = 1.0, length = 1.0, renderDistance = 240.0,
        transition = 380, fadeNear = 9.0, fadeFar = 55.0,
        glow = true, glowStrength = 0.65, pulse = true, flow = true,
        gradient = true, trail = false, sparkles = false, groundRing = true,
        laneAssist = true, laneOffset = 0.0,
        animationSpeed = 1.0, markerScale = 1.0
    }
}
