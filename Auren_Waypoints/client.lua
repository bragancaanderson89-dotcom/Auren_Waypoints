local C,G=WaypointConfig,WaypointGeometry
local settings=G.settings(nil,C.defaults)
local route,destination,custom={},nil,nil
local menuOpen,suppressed=false,false
local routeGeneration,activeKey,lastSave=0,nil,0
local warnedNative,markerVisible=false,false
local lastValidRoute,lastMarkerSeen=0,0
local laneOffset,laneUpdated=0,0
local kvp='settings:v2'
local raw=GetResourceKvpString(kvp) or GetResourceKvpString('settings:v1')
if raw then
    local ok,value=pcall(json.decode,raw)
    if ok then settings=G.settings(value,C.defaults) end
end

local function hideMarker()
    if markerVisible then SendNUIMessage({action='marker',visible=false}); markerVisible=false end
end
local function clearRoute(immediate)
    routeGeneration=routeGeneration+1
    if immediate then route={} else G.retireRoute(route,GetGameTimer(),settings.transition) end
    destination,activeKey=nil,nil
    lastValidRoute=0; laneOffset=0; laneUpdated=0
    hideMarker()
end
local function closeMenu()
    menuOpen=false
    if lastSave>0 then SetResourceKvp(kvp,json.encode(settings)); lastSave=0 end
    SetNuiFocus(false,false)
    SendNUIMessage({action='close'})
end
local function openMenu()
    if IsNuiFocused() and not menuOpen then return false end
    menuOpen=true; SetNuiFocus(true,true)
    SendNUIMessage({action='open',settings=settings,defaults=C.defaults,maxDistance=C.renderDistance})
    return true
end
RegisterCommand(C.command,function() if menuOpen then closeMenu() else openMenu() end end,false)
exports('OpenSettings',openMenu)
exports('SetVisible',function(value) suppressed=value==false; if suppressed then clearRoute(true) end end)

local function clearCustom()
    if custom and DoesBlipExist(custom.blip) then RemoveBlip(custom.blip) end
    custom=nil; clearRoute(false)
end
exports('ClearDestination',clearCustom)
exports('SetDestination',function(coords,label)
    if not G.validPoint(coords) then return false end
    clearCustom()
    local blip=AddBlipForCoord(coords.x,coords.y,coords.z)
    SetBlipSprite(blip,1); SetBlipColour(blip,3)
    SetBlipRoute(blip,true); SetBlipRouteColour(blip,3)
    local name=tostring(label or 'DESTINO'):sub(1,64)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(name); EndTextCommandSetBlipName(blip)
    custom={blip=blip,coords={x=coords.x,y=coords.y,z=coords.z},label=name}
    return true
end)
exports('GetSettings',function() return G.settings(settings,C.defaults) end)

RegisterNUICallback('ready',function(_,cb)
    cb({ok=true})
    if menuOpen then SendNUIMessage({action='open',settings=settings,defaults=C.defaults,maxDistance=C.renderDistance}) end
end)
RegisterNUICallback('close',function(_,cb) closeMenu(); cb({ok=true}) end)
RegisterNUICallback('settings',function(data,cb)
    if not menuOpen then cb({ok=false}); return end
    local nextSettings=G.settings(data,C.defaults)
    local changed=false
    for _,key in ipairs({'spacing','lift','scale','width','length','style','renderDistance','quality','laneAssist','laneOffset'}) do
        if nextSettings[key]~=settings[key] then changed=true; break end
    end
    settings=nextSettings
    if changed then routeGeneration=routeGeneration+1 end
    if not settings.road then G.retireRoute(route,GetGameTimer(),settings.transition) end
    lastSave=GetGameTimer()+500
    cb({ok=true,settings=settings})
end)

local function canRender()
    local ped=PlayerPedId()
    if suppressed or IsPauseMenuActive() or IsPlayerSwitchInProgress() or IsScreenFadedOut()
        or not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if not menuOpen and (IsNuiFocused() or not IsPlayerControlOn(PlayerId())) then return false end
    if C.onlyInVehicles then
        local vehicle=GetVehiclePedIsIn(ped,false)
        if vehicle==0 then return false end
        local class=GetVehicleClass(vehicle)
        if class==14 or class==15 or class==16 or class==21 then return false end
    end
    return true
end
local function getTarget()
    if custom then
        if DoesBlipExist(custom.blip) then return custom.coords,1,custom.label,'custom:'..custom.blip end
        custom=nil
    end
    if not IsWaypointActive() then return end
    local blip=GetFirstBlipInfoId(8)
    if blip==0 or not DoesBlipExist(blip) then return end
    local p=GetBlipInfoIdCoord(blip)
    return p,0,'DESTINO',('%.1f:%.1f'):format(p.x,p.y)
end
local function sample(distance,slot)
    local fn=GetPosAlongGpsTypeRoute or GetGpsWaypointRouteEnd
    if type(fn)~='function' then
        if not warnedNative then
            print('[Auren_Waypoints] Native GPS indisponível neste artifact. O marcador do destino continua disponível.')
            warnedNative=true
        end
        return nil
    end
    local ok,found,p=pcall(fn,true,math.max(0,distance)+0.0,slot)
    if not ok or not found or not G.validPoint(p) then return nil end
    if p.x==0 and p.y==0 and p.z==0 then return nil end
    return {x=p.x,y=p.y,z=p.z}
end
local function surface(p)
    local found,z=GetGroundZFor_3dCoord(p.x,p.y,p.z+2.0,false)
    -- Keep native altitude on bridges, elevated roads, tunnels and unloaded ground.
    if found and math.abs(z-p.z)<2.0 then return {x=p.x,y=p.y,z=z} end
    return p
end
local function targetHeight(p)
    local found,z=GetGroundZFor_3dCoord(p.x,p.y,p.z+35.0,false)
    if found then return z end
    if math.abs(p.z)>0.5 then return p.z end
    local ok,node=GetClosestVehicleNode(p.x,p.y,p.z,1,3.0,0)
    if ok and node and math.abs(node.x-p.x)<50 and math.abs(node.y-p.y)<50 then return node.z end
    return p.z
end

local function trackLane(probe,origin,forward,speed,now)
    local nearest,offset,alignment=12.0,nil,0
    for i=1,#probe-1 do
        local a,b=probe[i].p,probe[i+1].p
        local point,_,distance=G.project(origin,a,b)
        local dir=G.direction(a,b)
        if point and dir and probe[i].along<=16 and distance<nearest then
            nearest=distance
            alignment=forward.x*dir.x+forward.y*dir.y
            offset=(origin.x-point.x)*dir.y-(origin.y-point.y)*dir.x
        end
    end
    local dt=math.min(0.5,math.max(0.01,(now-laneUpdated)/1000))
    -- Hold the last lane through intersections, reversing and crossing the centerline.
    if settings.laneAssist and offset and alignment>0.78 and speed>1.0 then
        local target=G.clamp(offset,-C.maximumLaneOffset,C.maximumLaneOffset,0)
        laneOffset=laneOffset+(target-laneOffset)*(1-math.exp(-dt/0.32))
    elseif not settings.laneAssist then laneOffset=0 end
    laneUpdated=now
    return laneOffset+settings.laneOffset
end
local budgets={low=24,balanced=42,ultra=64}
CreateThread(function()
    while true do
        local now=GetGameTimer()
        if lastSave>0 and now>=lastSave then SetResourceKvp(kvp,json.encode(settings)); lastSave=0 end
        if not canRender() then clearRoute(true); Wait(200)
        else
            local target,slot,label,key=getTarget()
            if not target then
                if activeKey or destination then clearRoute(false) end
                Wait(180)
            else
                if key~=activeKey then clearRoute(false); activeKey=key end
                local ped=PlayerPedId()
                local vehicle=GetVehiclePedIsIn(ped,false)
                local entity=vehicle~=0 and vehicle or ped
                local origin,forward=GetEntityCoords(entity),GetEntityForwardVector(entity)
                local dist=math.sqrt((origin.x-target.x)^2+(origin.y-target.y)^2)
                local groundZ=destination and destination.z or targetHeight(target)
                if dist<150 then groundZ=targetHeight(target) end
                destination={x=target.x,y=target.y,z=groundZ,label=label,distance=dist}
                if dist<C.arrivalDistance and math.abs(origin.z-groundZ)<10 then
                    G.retireRoute(route,now,settings.transition); hideMarker()
                    if custom then clearCustom() end
                    Wait(180)
                elseif not settings.road then
                    G.retireRoute(route,now,settings.transition); Wait(150)
                else
                    local generation,snapshot=routeGeneration,settings
                    local probe,pending={},{}
                    local limit=math.min(C.maximumChevrons,budgets[snapshot.quality])
                    -- One dense curve supplies every arrow's position and tangent.
                    -- Limit native work to the visible arrow budget, with endpoint padding.
                    local reach=math.min(snapshot.renderDistance+8,12+limit*snapshot.spacing)
                    local raw={}
                    for distance=0,reach,2 do
                        local p=sample(distance,slot)
                        if not p then break end
                        raw[#raw+1]={p=p,along=distance}
                        if #raw%32==0 then Wait(0) end
                        if generation~=routeGeneration then break end
                    end
                    local curve=G.curve(raw)
                    for _,node in ipairs(curve) do
                        if node.along<=48 then probe[#probe+1]=node end
                    end
                    local lane=trackLane(probe,origin,forward,GetEntitySpeed(entity),now)
                    local distance=G.routePhase(route,probe,snapshot.spacing)
                    local iterations=0
                    while distance<snapshot.renderDistance and #pending<limit do
                        local center,dir=G.curveAt(curve,distance)
                        if not center then break end
                        if G.distance(origin,center)>snapshot.renderDistance+40 then break end
                        if dir then
                            center=surface(center)
                            local entry=G.buildEntry(center,dir,snapshot,distance,lane)
                            local grounded=surface(entry.p)
                            local dz=grounded.z-entry.p.z
                            if math.abs(dz)>0.01 then
                                entry.p=grounded
                                for _,mesh in ipairs({entry.vertices,entry.glow,entry.halo}) do
                                    for _,v in ipairs(mesh) do v.z=v.z+dz end
                                end
                            end
                            pending[#pending+1]=entry
                        end
                        iterations=iterations+1; distance=distance+snapshot.spacing
                        if iterations%10==0 then Wait(0) end
                        if generation~=routeGeneration then break end
                    end
                    if generation==routeGeneration then
                        local finished=GetGameTimer()
                        if #pending>0 then
                            lastValidRoute=finished
                            route=G.prepareRoute(route,pending,finished,snapshot.transition,snapshot.spacing,limit)
                        elseif finished-lastValidRoute>C.routeGracePeriod then
                            G.retireRoute(route,finished,snapshot.transition)
                        end
                    end
                    Wait(C.sampleInterval)
                end
            end
        end
    end
end)

local function mesh(vertices,r,g,b,alpha)
    if alpha<1 then return end
    for i=1,#vertices,3 do
        local a,c,d=vertices[i],vertices[i+1],vertices[i+2]
        DrawPoly(a.x,a.y,a.z,c.x,c.y,c.z,d.x,d.y,d.z,r,g,b,alpha)
    end
end
local ring={}
for i=0,32 do ring[i+1]={x=math.cos(i*math.pi/16),y=math.sin(i*math.pi/16)} end
local function drawRing(d,radius,alpha,r,g,b)
    if alpha<1 then return end
    local inner=radius-0.12; local z=d.z+0.12
    for i=1,32 do
        local a,c=ring[i],ring[i+1]
        DrawPoly(d.x+a.x*inner,d.y+a.y*inner,z,d.x+a.x*radius,d.y+a.y*radius,z,
            d.x+c.x*radius,d.y+c.y*radius,z,r,g,b,alpha)
        DrawPoly(d.x+a.x*inner,d.y+a.y*inner,z,d.x+c.x*radius,d.y+c.y*radius,z,
            d.x+c.x*inner,d.y+c.y*inner,z,r,g,b,alpha)
    end
end
CreateThread(function()
    while true do
        if (#route>0 or (destination and settings.groundRing and settings.destination)) and canRender() then
            local ped=PlayerPedId(); local vehicle=GetVehiclePedIsIn(ped,false)
            local entity=vehicle~=0 and vehicle or ped
            local origin,forward=GetEntityCoords(entity),GetEntityForwardVector(entity)
            local r,g,b=G.rgb(settings.color); local sr,sg,sb=G.rgb(settings.secondaryColor)
            local now=GetGameTimer(); local time=now*0.001*settings.animationSpeed
            local live=0
            for index=#route,1,-1 do
                local entry=route[index]
                G.animateEntry(entry,now)
                if entry.retiring and entry.finished then table.remove(route,index)
                else
                    local d=G.distance(origin,entry.p)
                    local fade=G.passFade(entry,origin,forward,now,settings.fadeNear)
                        *G.smooth((settings.renderDistance-d)/settings.fadeFar)
                    local pulse=settings.pulse and (0.88+0.12*math.sin(time*2.4)) or 1
                    local effectPhase=entry.effectPhase or entry.along
                    local wave=settings.flow and (0.80+0.20*math.sin(time*3.2-effectPhase*0.065)) or 1
                    local a=math.floor(255*settings.opacity*fade*entry.alpha*pulse*wave)
                    if a>1 and d<settings.renderDistance+20 then
                        live=live+1
                        local mix=settings.gradient and G.clamp(d/settings.renderDistance,0,1,0) or 0
                        local cr,cg,cb=math.floor(r+(sr-r)*mix),math.floor(g+(sg-g)*mix),math.floor(b+(sb-b)*mix)
                        if settings.glow and settings.quality~='low' then
                            if settings.quality=='ultra' then mesh(entry.halo,cr,cg,cb,math.floor(a*0.08*settings.glowStrength)) end
                            mesh(entry.glow,cr,cg,cb,math.floor(a*0.24*settings.glowStrength))
                        end
                        mesh(entry.vertices,cr,cg,cb,a)
                        if settings.trail and settings.quality~='low' and d<100 then
                            local p,dir=entry.p,entry.dir
                            DrawLine(p.x-dir.x*3,p.y-dir.y*3,p.z+settings.lift,
                                p.x-dir.x*1.4,p.y-dir.y*1.4,p.z+settings.lift,cr,cg,cb,math.floor(a*0.5))
                        end
                        if settings.sparkles and settings.quality~='low' and live<=10 and d<90 then
                            local p=entry.p; local h=0.20+0.16*math.sin(time*2+effectPhase)
                            local x,y,z=p.x+math.cos(effectPhase)*0.8,p.y+math.sin(effectPhase)*0.8,p.z+settings.lift+h
                            local size=0.06
                            DrawPoly(x-size,y,z,x,y-size,z,x+size,y,z,225,245,255,math.floor(a*0.65))
                            DrawPoly(x-size,y,z,x+size,y,z,x,y+size,z,225,245,255,math.floor(a*0.65))
                        end
                    end
                end
            end
            local d=destination
            if d and settings.destination and settings.groundRing and G.distance(origin,d)<140 and d.distance>=C.arrivalDistance then
                local alpha=math.floor(130*settings.opacity*G.smooth((140-G.distance(origin,d))/45))
                drawRing(d,2.6,alpha,r,g,b)
                if settings.quality~='low' then
                    local phase=(time*0.45)%1
                    drawRing(d,2.6+phase*3.5,math.floor(alpha*(1-phase)^2),r,g,b)
                end
            end
            Wait(0)
        else Wait(80) end
    end
end)
CreateThread(function()
    while true do
        local d=destination
        if d and settings.destination and canRender() and d.distance>=C.arrivalDistance and d.distance<C.markerDistance then
            local ped=PlayerPedId(); local origin=GetEntityCoords(ped)
            local distance=math.sqrt((origin.x-d.x)^2+(origin.y-d.y)^2)
            local onScreen,x,y=GetScreenCoordFromWorldCoord(d.x,d.y,d.z+C.markerHeight)
            local baseVisible,_,by=GetScreenCoordFromWorldCoord(d.x,d.y,d.z+0.5)
            local now=GetGameTimer()
            if onScreen and x>0.02 and x<0.98 and y>0.04 and y<0.91 then
                SendNUIMessage({action='marker',visible=true,x=x,y=y,
                    bottom=baseVisible and math.min(by,0.96) or y+0.12,distance=distance,label=d.label,
                    color=settings.color,secondaryColor=settings.secondaryColor,style=settings.destinationStyle,
                    scale=settings.markerScale,pulse=settings.pulse,speed=settings.animationSpeed})
                markerVisible=true; lastMarkerSeen=now
            elseif now-lastMarkerSeen>120 then hideMarker() end
            Wait(C.markerInterval)
        else hideMarker(); Wait(120) end
    end
end)
CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0,1,true); DisableControlAction(0,2,true)
            DisableControlAction(0,24,true); DisableControlAction(0,25,true)
            DisableControlAction(0,75,true); DisableControlAction(0,200,true)
            if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then closeMenu() end
            Wait(0)
        else Wait(160) end
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    SetResourceKvp(kvp,json.encode(settings))
    if menuOpen then SetNuiFocus(false,false) end
    if custom and DoesBlipExist(custom.blip) then RemoveBlip(custom.blip) end
end)
