local V={}
local tracked={}
local byEntity={}
local chars='ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
local function plate()
    for _=1,20 do
        local t={};for i=1,8 do local n=math.random(1,#chars);t[i]=chars:sub(n,n) end
        local p=table.concat(t)
        if not MySQL.scalar.await('SELECT 1 FROM szcore_vehicles WHERE plate=?',{p}) then return p end
    end
end
local function decodeRow(r)
    if not r then return nil end
    local ok,x=pcall(json.decode,r.props or '{}');r.props=ok and x or {}
    local ok2,y=pcall(json.decode,r.last_position or '{}');r.last_position=ok2 and y or {}
    return r
end
function V.create(citizenid,model,props,garage,customPlate,vehicleType)
    local p=customPlate or plate();if not p then return nil end
    local id=MySQL.insert.await([[INSERT INTO szcore_vehicles (citizenid,plate,model,vehicle_type,props,garage,state) VALUES (?,?,?,?,?,?,'stored')]],{citizenid,p,model,vehicleType or 'automobile',json.encode(props or {}),garage or 'legion'})
    if id then
        MySQL.prepare.await("INSERT INTO szcore_vehicle_keys (vehicle_id,citizenid,key_type) VALUES (?,?,'owner')",{id,citizenid})
        return {id=id,plate=p}
    end
    return nil
end
function V.getByPlate(p)return decodeRow(MySQL.single.await('SELECT * FROM szcore_vehicles WHERE plate=?',{p}))end
function V.getById(id)return decodeRow(MySQL.single.await('SELECT * FROM szcore_vehicles WHERE id=?',{id}))end
function V.getOwned(cid)local rows=MySQL.query.await('SELECT * FROM szcore_vehicles WHERE citizenid=? ORDER BY id DESC',{cid}) or {};for i=1,#rows do decodeRow(rows[i]) end;return rows end
function V.transfer(id,newCid)
    local ok=MySQL.startTransaction(function(query)
        local rows=query('SELECT id FROM szcore_vehicles WHERE id=? FOR UPDATE',{id})
        if not rows or not rows[1] then return false end
        local target=query('SELECT citizenid FROM szcore_characters WHERE citizenid=?',{newCid});if not target or not target[1]then return false end
        query('UPDATE szcore_vehicles SET citizenid=? WHERE id=?',{newCid,id})
        query('DELETE FROM szcore_vehicle_keys WHERE vehicle_id=?',{id})
        query("INSERT INTO szcore_vehicle_keys (vehicle_id,citizenid,key_type) VALUES (?,?,'owner')",{id,newCid})
        return true
    end)
    if ok and tracked[id] and DoesEntityExist(tracked[id].entity)then Entity(tracked[id].entity).state:set('szcoreOwner',newCid,true)end
    return ok==true
end
function V.updateState(id,state,garage,pos,props)
    return MySQL.update.await('UPDATE szcore_vehicles SET state=?,garage=COALESCE(?,garage),last_position=COALESCE(?,last_position),props=COALESCE(?,props) WHERE id=?',{state,garage,pos and json.encode(pos) or nil,props and json.encode(props) or nil,id})>0
end
function V.delete(id)return MySQL.update.await('DELETE FROM szcore_vehicles WHERE id=?',{id})>0 end
local function registerEntity(vehicle,row)
    if vehicle and vehicle~=0 and DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('szcoreVehicleId',row.id,true)
        Entity(vehicle).state:set('szcoreOwner',row.citizenid,true)
        Entity(vehicle).state:set('szcoreVehicleProps',row.props or {},true)
        byEntity[vehicle]=row.id
        local c=GetEntityCoords(vehicle);tracked[row.id]={entity=vehicle,x=c.x,y=c.y,z=c.z}
    end
end
function V.spawnRecord(row,coords)
    if not row or not coords then return nil end
    local existing=tracked[row.id];if existing and DoesEntityExist(existing.entity)then return existing.entity end
    local model=type(row.model)=='number' and row.model or joaat(row.model)
    local v=CreateVehicleServerSetter(model,row.vehicle_type or 'automobile',coords.x,coords.y,coords.z,coords.w or 0.0)
    if not v or v==0 then return nil end
    SetVehicleNumberPlateText(v,row.plate);registerEntity(v,row);return v
end
CreateThread(function()
    while not exports.szcore:IsReady()do Wait(100)end
    Wait(2500)
    local rows=MySQL.query.await("SELECT * FROM szcore_vehicles WHERE state='out' AND last_position IS NOT NULL") or {}
    local existing={}
    for _,e in ipairs(GetAllVehicles())do local id=Entity(e).state.szcoreVehicleId;if id then existing[tonumber(id)]=e end end
    for i=1,#rows do
        local r=decodeRow(rows[i]);local p=r.last_position;local e=existing[tonumber(r.id)]
        if e and GetVehicleNumberPlateText(e):gsub('%s+$','')==r.plate then registerEntity(e,r)
        elseif p and p.x then V.spawnRecord(r,p) end
        if i%20==0 then Wait(0) end
    end
    while true do
        Wait(60000)
        local queries={}
        for id,t in pairs(tracked) do
            local v=t.entity
            if not v or v==0 or not DoesEntityExist(v) then tracked[id]=nil
            else
                local c=GetEntityCoords(v);local dx,dy,dz=c.x-t.x,c.y-t.y,c.z-t.z
                if dx*dx+dy*dy+dz*dz>=4.0 then
                    local pos=json.encode({x=c.x,y=c.y,z=c.z,w=GetEntityHeading(v)})
                    queries[#queries+1]={query='UPDATE szcore_vehicles SET last_position=? WHERE id=?',values={pos,id}}
                    t.x,t.y,t.z=c.x,c.y,c.z
                end
            end
        end
        if #queries>0 then MySQL.transaction.await(queries) end
    end
end)
exports('CreateOwnedVehicle',V.create)
exports('GetVehicleByPlate',V.getByPlate)
exports('GetVehicleById',V.getById)
exports('GetOwnedVehicles',V.getOwned)
exports('TransferVehicle',V.transfer)
exports('UpdateVehicleState',V.updateState)
exports('DeleteVehicle',V.delete)
exports('SpawnPersistentVehicle',V.spawnRecord)
exports('GetRecordByEntity',function(entity)local id=byEntity[entity];return id and V.getById(id)or nil end)
AddEventHandler('entityRemoved',function(entity)local id=byEntity[entity];byEntity[entity]=nil;if id and tracked[id]and tracked[id].entity==entity then tracked[id]=nil end end)
