WaypointGeometry = {}
local G = WaypointGeometry
local axes = {'x','y','z'}
local meshKeys = {'vertices','glow','halo'}
local styles = {chevron=true,double=true,arrow=true,diamond=true,bar=true,split=true}
local qualities = {low=true,balanced=true,ultra=true}
local markerStyles = {beacon=true,minimal=true,orbit=true}

function G.finite(n)
    return type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
function G.clamp(n,lo,hi,fallback)
    if not G.finite(n) then return fallback end
    return math.max(lo,math.min(hi,n))
end
function G.settings(input,defaults)
    input = type(input)=='table' and input or {}
    local result = {}
    for key,value in pairs(defaults) do result[key]=value end
    for _,key in ipairs({'road','destination','glow','pulse','flow','gradient','trail','sparkles','groundRing','laneAssist'}) do
        if type(input[key])=='boolean' then result[key]=input[key] end
    end
    for _,key in ipairs({'color','secondaryColor'}) do
        if type(input[key])=='string' and input[key]:match('^#%x%x%x%x%x%x$') then result[key]=input[key]:lower() end
    end
    for key,allowed in pairs({style=styles,quality=qualities,destinationStyle=markerStyles}) do
        if type(input[key])=='string' and allowed[input[key]] then result[key]=input[key] end
    end
    local ranges = {
        spacing={4,20},opacity={0.1,1},lift={0.06,1.5},scale={0.5,2},
        width={0.5,1.8},length={0.5,1.8},renderDistance={80,WaypointConfig.renderDistance},
        transition={180,1000},fadeNear={3,20},fadeFar={20,100},laneOffset={-3,3},
        glowStrength={0,1},animationSpeed={0.25,2.5},markerScale={0.7,1.4}
    }
    for key,range in pairs(ranges) do result[key]=G.clamp(input[key],range[1],range[2],defaults[key]) end
    return result
end
function G.rgb(hex)
    return tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16)
end
function G.distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
function G.validPoint(p)
    local kind = type(p)
    if kind~='table' and kind~='vector3' and kind~='vector4' then return false end
    return G.finite(p.x) and G.finite(p.y) and G.finite(p.z)
        and math.abs(p.x)<20000 and math.abs(p.y)<20000 and math.abs(p.z)<2500
end
function G.smooth(t)
    t = math.max(0,math.min(1,t))
    return t*t*(3-2*t)
end
function G.direction(p,q)
    local dx,dy,dz = q.x-p.x,q.y-p.y,q.z-p.z
    local length = math.sqrt(dx*dx+dy*dy)
    if length<0.1 or length>35 or math.abs(dz)>length*0.8 then return nil end
    return {x=dx/length,y=dy/length,z=dz/length}
end
function G.project(p,a,b)
    local dx,dy,dz = b.x-a.x,b.y-a.y,b.z-a.z
    local len2 = dx*dx+dy*dy+dz*dz
    if len2<0.01 then return nil end
    local t = math.max(0,math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy+(p.z-a.z)*dz)/len2))
    local q = {x=a.x+dx*t,y=a.y+dy*t,z=a.z+dz*t}
    return q,t,G.distance(p,q)
end

-- Sample a single continuous road curve. Orienting each arrow from its own native
-- +/-3m segment exposes GPS node corners and gives neighbouring arrows unrelated
-- headings. A cubic B-spline keeps position and direction continuous through nodes.
function G.curve(samples)
    local nodes={}
    for _,sample in ipairs(samples) do
        if G.validPoint(sample.p) and G.finite(sample.along) then
            nodes[#nodes+1]={along=sample.along,p={x=sample.p.x,y=sample.p.y,z=sample.p.z}}
        end
    end
    if #nodes<2 then return nodes end
    local repaired={}
    for i,node in ipairs(nodes) do
        local p=node.p
        -- An isolated sideways GPS spike has parallel approach/exit segments.
        -- A genuine junction or U-turn does not satisfy this test.
        if i>2 and i<#nodes-1 then
            local a,b=nodes[i-1].p,nodes[i+1].p
            local before,after=G.direction(nodes[i-2].p,a),G.direction(b,nodes[i+2].p)
            local q,_,error=G.project(p,a,b)
            if q and before and after and before.x*after.x+before.y*after.y>0.85
                and error>2.0 and G.distance(a,p)+G.distance(p,b)>G.distance(a,b)*1.7
                and math.abs(q.z-p.z)<1.0 then p=q end
        end
        repaired[i]={x=p.x,y=p.y,z=p.z}
    end
    local weights={1,4,6,4,1}
    for i,node in ipairs(nodes) do
        node.p=repaired[i]
        if i>2 and i<#nodes-1 then
            local p={x=0,y=0,z=0}
            for k=-2,2 do
                for _,axis in ipairs(axes) do p[axis]=p[axis]+repaired[i+k][axis]*weights[k+3]/16 end
            end
            -- Limit corner cutting; keep the curve inside the native road corridor.
            local move=G.distance(node.p,p)
            local amount=move>0.5 and 0.5/move or 1
            node.p={x=node.p.x+(p.x-node.p.x)*amount,y=node.p.y+(p.y-node.p.y)*amount,z=node.p.z+(p.z-node.p.z)*amount}
        end
    end
    return nodes
end
function G.curveAt(nodes,distance)
    if #nodes<2 or distance<nodes[1].along or distance>nodes[#nodes].along then return nil end
    local lo,hi=1,#nodes-1
    while lo<hi do
        local mid=math.floor((lo+hi+1)/2)
        if nodes[mid].along<=distance then lo=mid else hi=mid-1 end
    end
    local a,b=nodes[lo],nodes[lo+1]
    local h=b.along-a.along
    if h<=0 or G.distance(a.p,b.p)>math.max(12,h*3) then return nil end
    local t=(distance-a.along)/h
    local p,velocity={},{}
    for _,axis in ipairs(axes) do
        local x,y=a.p[axis],b.p[axis]
        local before=nodes[lo-1] and nodes[lo-1].p[axis] or 2*x-y
        local after=nodes[lo+2] and nodes[lo+2].p[axis] or 2*y-x
        p[axis]=((1-t)^3*before+(3*t^3-6*t*t+4)*x+(-3*t^3+3*t*t+3*t+1)*y+t^3*after)/6
        velocity[axis]=(-3*(1-t)^2*before+(9*t*t-12*t)*x+(-9*t*t+6*t+3)*y+3*t*t*after)/(6*h)
    end
    local length=math.sqrt(velocity.x^2+velocity.y^2)
    if length<0.05 or math.abs(velocity.z)>length*0.8 then return nil end
    return p,{x=velocity.x/length,y=velocity.y/length,z=velocity.z/length}
end

-- Ignore isolated native-heading spikes at an already anchored point. A sustained
-- change is accepted on the third sample, allowing genuine recalculated routes.
function G.stableHeading(previous,center,dir)
    local nearest,best=nil,1.25
    for _,old in ipairs(previous) do
        if not old.retiring then
            local d=G.distance(center,old.center)
            if d<best then nearest,best=old,d end
        end
    end
    if nearest and nearest.dir.x*dir.x+nearest.dir.y*dir.y<0.72 then
        local rejected=(nearest.headingDrops or 0)+1
        if rejected<=2 then return nearest.dir,rejected end
    end
    return dir,0
end

local shapes = {
    chevron={{{-1.35,-0.70},{0,0.75},{0,0.20},{-1.35,-1.25}},{{0,0.75},{1.35,-0.70},{1.35,-1.25},{0,0.20}}},
    double={{{-1.2,0.10},{0,1.15},{0,0.70},{-1.2,-0.35}},{{0,1.15},{1.2,0.10},{1.2,-0.35},{0,0.70}},
        {{-1.2,-1.05},{0,0},{0,-0.45},{-1.2,-1.5}},{{0,0},{1.2,-1.05},{1.2,-1.5},{0,-0.45}}},
    arrow={{{-1.2,-0.25},{0,1.35},{1.2,-0.25}},{{-0.34,-1.45},{-0.34,-0.25},{0.34,-0.25},{0.34,-1.45}}},
    diamond={{{-0.95,0},{0,1.4},{0.95,0},{0,-1.4}}},
    bar={{{-1.3,-0.45},{-1.3,0.45},{1.3,0.45},{1.3,-0.45}}},
    split={{{-1.45,-1.15},{-0.20,0.45},{-0.65,0.45},{-1.75,-0.95}},
        {{0.2,0.45},{1.45,-1.15},{1.75,-0.95},{0.65,0.45}},{{-0.38,0.8},{0,1.3},{0.38,0.8}}}
}
function G.mesh(p,dir,s,expansion,liftOffset)
    local mesh = {}
    for _,polygon in ipairs(shapes[s.style] or shapes.chevron) do
        local vertices = {}
        for _,v in ipairs(polygon) do
            local side,forward = v[1]*s.scale*s.width*expansion,v[2]*s.scale*s.length*expansion
            vertices[#vertices+1] = {x=p.x+dir.y*side+dir.x*forward,
                y=p.y-dir.x*side+dir.y*forward,z=p.z+s.lift+dir.z*forward+(liftOffset or 0)}
        end
        for i=2,#vertices-1 do
            local a,b,c = vertices[1],vertices[i],vertices[i+1]
            local cross = (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
            mesh[#mesh+1]=a; mesh[#mesh+1]=cross>0 and b or c; mesh[#mesh+1]=cross>0 and c or b
        end
    end
    return mesh
end
function G.buildEntry(center,dir,s,distance,lane)
    local p = {x=center.x+dir.y*lane,y=center.y-dir.x*lane,z=center.z}
    return {p=p,center=center,dir=dir,along=distance,
        signature=table.concat({s.style,s.scale,s.width,s.length,s.lift},':'),
        vertices=G.mesh(p,dir,s,1,0),glow=G.mesh(p,dir,s,1.16,-0.025),halo=G.mesh(p,dir,s,1.36,-0.045)}
end
function G.routePhase(previous,probe,spacing)
    local bestDistance,bestError = nil,2.25
    for _,old in ipairs(previous) do
        if not old.retiring then
            for i=1,#probe-1 do
                local a,b = probe[i],probe[i+1]
                local _,t,error = G.project(old.center,a.p,b.p)
                local dir = G.direction(a.p,b.p)
                local along = t and a.along+(b.along-a.along)*t or 0
                if dir and along>=3 and error<bestError and old.dir.x*dir.x+old.dir.y*dir.y>0.65 then
                    bestDistance,bestError=along,error
                end
            end
        end
    end
    if not bestDistance then return 5 end
    local phase = bestDistance%spacing
    if phase<3 then phase=phase+spacing end
    return phase
end

function G.animateEntry(entry,now)
    if entry.finished then return end
    local t = G.smooth((now-entry.started)/math.max(math.min(entry.duration,150),1))
    local alphaT = G.smooth((now-(entry.alphaStarted or entry.started))/math.max(entry.duration,1))
    local alphaFrom = entry.alphaFrom or entry.fromAlpha
    entry.alpha=alphaFrom+((entry.retiring and 0 or 1)-alphaFrom)*alphaT
    if not entry.retiring and entry.fromMesh then
        for _,key in ipairs(meshKeys) do
            local source,target=entry.fromMesh[key],entry.targetMesh[key]
            for i,v in ipairs(entry[key]) do
                for _,axis in ipairs(axes) do v[axis]=source[i][axis]+(target[i][axis]-source[i][axis])*t end
            end
        end
    end
    entry.finished=t>=1 and alphaT>=1
end
function G.retireRoute(route,now,duration)
    for _,entry in ipairs(route) do
        if not entry.retiring then
            G.animateEntry(entry,now)
            entry.retiring,entry.fromAlpha,entry.started,entry.duration,entry.finished=true,entry.alpha or 1,now,duration,false
            entry.alphaStarted,entry.alphaFrom=now,entry.alpha or 1
        end
    end
    return route
end
function G.prepareRoute(previous,pending,now,duration,spacing,limit)
    local used,merged,phaseOffset = {},{},0
    for _,entry in ipairs(pending) do
        local best,distance = nil,math.min(spacing*0.55,4.5)
        for index,old in ipairs(previous) do
            G.animateEntry(old,now)
            local d=G.distance(entry.center,old.center)
            if not used[index] and old.signature==entry.signature and d<distance
                and old.dir.x*entry.dir.x+old.dir.y*entry.dir.y>0.65 then best,distance=index,d end
        end
        entry.started,entry.duration,entry.finished=now,duration,false
        entry.alpha,entry.fromAlpha=0,0
        entry.alphaStarted,entry.alphaFrom=now,0
        entry.effectPhase=entry.along+phaseOffset
        if best then
            local old=previous[best]; used[best]=true
            entry.effectPhase=old.effectPhase or old.along
            phaseOffset=entry.effectPhase-entry.along
            entry.fromAlpha,entry.alpha=old.alpha or 1,old.alpha or 1
            entry.passAlpha,entry.fadeTime,entry.passed=old.passAlpha,old.fadeTime,old.passed
            if old.retiring or entry.alpha>=0.9999 then entry.alphaFrom=entry.fromAlpha
            else entry.alphaStarted,entry.alphaFrom=old.alphaStarted or old.started,old.alphaFrom or old.fromAlpha end
            if G.distance(entry.p,old.p)<0.12 and distance<0.12
                and old.dir.x*entry.dir.x+old.dir.y*entry.dir.y>0.9998
                and math.abs(old.dir.z-entry.dir.z)<0.002 then
                entry.p,entry.center,entry.dir=old.p,old.center,old.dir
                entry.vertices,entry.glow,entry.halo=old.vertices,old.glow,old.halo
            else
                entry.fromMesh,entry.targetMesh={},{}
                for _,key in ipairs(meshKeys) do
                    entry.fromMesh[key],entry.targetMesh[key]=old[key],entry[key]
                    local mesh={}
                    for i,v in ipairs(old[key]) do mesh[i]={x=v.x,y=v.y,z=v.z} end
                    entry[key]=mesh
                end
            end
        end
        merged[#merged+1]=entry
    end
    local retired={}
    for index,old in ipairs(previous) do
        if not used[index] then
            G.retireRoute({old},now,duration); G.animateEntry(old,now)
            if old.alpha>0.005 then retired[#retired+1]=old end
        end
    end
    table.sort(retired,function(a,b) return a.alpha>b.alpha end)
    for i=1,math.min(#retired,limit or #pending) do merged[#merged+1]=retired[i] end
    return merged
end

-- Longitudinal fade follows travel direction, so an arrow stays gone after passing it.
-- Time filtering handles fast movement without toggling visibility at a distance threshold.
function G.passFade(entry,origin,vehicleForward,now,near)
    local ahead=(entry.p.x-origin.x)*entry.dir.x+(entry.p.y-origin.y)*entry.dir.y
    local aligned=not vehicleForward or vehicleForward.x*entry.dir.x+vehicleForward.y*entry.dir.y>0.35
    local wanted=aligned and G.smooth((ahead-0.7)/near) or G.smooth((G.distance(origin,entry.p)-1.2)/near)
    if aligned and ahead < -1.8 then entry.passed=true end
    if entry.passed then wanted=0 end
    local dt=math.min(100,math.max(0,now-(entry.fadeTime or now)))
    entry.passAlpha=(entry.passAlpha or wanted)+(wanted-(entry.passAlpha or wanted))*(1-math.exp(-dt/65))
    entry.fadeTime=now
    return entry.passAlpha
end
