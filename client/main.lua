local function getMods(vehicle)
    local mods={};SetVehicleModKit(vehicle,0)
    for i=0,49 do mods[tostring(i)]=GetVehicleMod(vehicle,i) end
    mods.turbo=IsToggleModOn(vehicle,18);mods.xenon=IsToggleModOn(vehicle,22)
    return mods
end
local function getProps(vehicle)
    if not vehicle or vehicle==0 or not DoesEntityExist(vehicle) then return nil end
    local c1,c2=GetVehicleColours(vehicle);local p,e=GetVehicleExtraColours(vehicle);local nr,ng,nb=GetVehicleNeonLightsColour(vehicle);local sr,sg,sb=GetVehicleTyreSmokeColor(vehicle)
    local extras={};for i=0,20 do if DoesExtraExist(vehicle,i) then extras[tostring(i)]=IsVehicleExtraTurnedOn(vehicle,i) end end
    local neon={};for i=0,3 do neon[tostring(i)]=IsVehicleNeonLightEnabled(vehicle,i) end
    local brokenDoors={};for i=0,5 do if IsVehicleDoorDamaged(vehicle,i) then brokenDoors[tostring(i)]=true end end
    local brokenWindows={};for i=0,7 do if not IsVehicleWindowIntact(vehicle,i) then brokenWindows[tostring(i)]=true end end
    local burstTyres={};for i=0,7 do if IsVehicleTyreBurst(vehicle,i,false) then burstTyres[tostring(i)]=true end end
    return {
        model=GetEntityModel(vehicle),plate=GetVehicleNumberPlateText(vehicle),plateIndex=GetVehicleNumberPlateTextIndex(vehicle),
        color1=c1,color2=c2,pearlescentColor=p,wheelColor=e,wheelType=GetVehicleWheelType(vehicle),windowTint=GetVehicleWindowTint(vehicle),
        dirt=GetVehicleDirtLevel(vehicle),engineHealth=GetVehicleEngineHealth(vehicle),bodyHealth=GetVehicleBodyHealth(vehicle),tankHealth=GetVehiclePetrolTankHealth(vehicle),fuel=GetVehicleFuelLevel(vehicle),
        livery=GetVehicleLivery(vehicle),mods=getMods(vehicle),extras=extras,neon=neon,neonColor={nr,ng,nb},smokeColor={sr,sg,sb},
        tyresCanBurst=GetVehicleTyresCanBurst(vehicle),brokenDoors=brokenDoors,brokenWindows=brokenWindows,burstTyres=burstTyres
    }
end
local function apply(vehicle,p)
    if not vehicle or vehicle==0 or not DoesEntityExist(vehicle) or type(p)~='table' then return false end
    SetVehicleModKit(vehicle,0)
    if p.plate then SetVehicleNumberPlateText(vehicle,tostring(p.plate)) end
    if p.plateIndex then SetVehicleNumberPlateTextIndex(vehicle,tonumber(p.plateIndex) or 0) end
    if p.color1 and p.color2 then SetVehicleColours(vehicle,p.color1,p.color2) end
    if p.pearlescentColor and p.wheelColor then SetVehicleExtraColours(vehicle,p.pearlescentColor,p.wheelColor) end
    if p.wheelType then SetVehicleWheelType(vehicle,p.wheelType) end
    if p.windowTint then SetVehicleWindowTint(vehicle,p.windowTint) end
    if p.mods then
        for k,v in pairs(p.mods) do local id=tonumber(k);if id and type(v)=='number' then SetVehicleMod(vehicle,id,v,false) end end
        if p.mods.turbo~=nil then ToggleVehicleMod(vehicle,18,p.mods.turbo==true) end;if p.mods.xenon~=nil then ToggleVehicleMod(vehicle,22,p.mods.xenon==true) end
    end
    if p.extras then for k,v in pairs(p.extras) do local id=tonumber(k);if id and DoesExtraExist(vehicle,id) then SetVehicleExtra(vehicle,id,v and 0 or 1) end end end
    if p.neon then for k,v in pairs(p.neon) do local id=tonumber(k);if id then SetVehicleNeonLightEnabled(vehicle,id,v==true) end end end
    if p.neonColor then SetVehicleNeonLightsColour(vehicle,p.neonColor[1] or 255,p.neonColor[2] or 255,p.neonColor[3] or 255) end
    if p.smokeColor then SetVehicleTyreSmokeColor(vehicle,p.smokeColor[1] or 255,p.smokeColor[2] or 255,p.smokeColor[3] or 255) end
    if p.livery and p.livery>=0 then SetVehicleLivery(vehicle,p.livery) end
    if p.tyresCanBurst~=nil then SetVehicleTyresCanBurst(vehicle,p.tyresCanBurst==true) end
    if p.brokenDoors then for k,v in pairs(p.brokenDoors) do local id=tonumber(k);if id and v then SetVehicleDoorBroken(vehicle,id,true) end end end
    if p.brokenWindows then for k,v in pairs(p.brokenWindows) do local id=tonumber(k);if id and v then SmashVehicleWindow(vehicle,id) end end end
    if p.burstTyres then for k,v in pairs(p.burstTyres) do local id=tonumber(k);if id and v then SetVehicleTyreBurst(vehicle,id,false,1000.0) end end end
    if p.dirt then SetVehicleDirtLevel(vehicle,p.dirt+0.0) end
    if p.engineHealth then SetVehicleEngineHealth(vehicle,p.engineHealth+0.0) end
    if p.bodyHealth then SetVehicleBodyHealth(vehicle,p.bodyHealth+0.0) end
    if p.tankHealth then SetVehiclePetrolTankHealth(vehicle,p.tankHealth+0.0) end
    if p.fuel then SetVehicleFuelLevel(vehicle,p.fuel+0.0) end
    return true
end
AddStateBagChangeHandler('szcoreVehicleProps',nil,function(bagName,_,value)
    if type(value)~='table' then return end
    CreateThread(function()
        local entity=0;local timeout=GetGameTimer()+5000
        while entity==0 and GetGameTimer()<timeout do entity=GetEntityFromStateBagName(bagName);if entity==0 then Wait(50) end end
        if entity~=0 then apply(entity,value) end
    end)
end)
exports('GetVehicleProperties',getProps);exports('SetVehicleProperties',apply)
