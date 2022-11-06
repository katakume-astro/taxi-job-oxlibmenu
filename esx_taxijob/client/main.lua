local HasAlreadyEnteredMarker, OnJob, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle,
    CurrentActionData = false, false, false, false, false, {}
local CurrentCustomer, CurrentCustomerBlip, DestinationBlip, targetCoords, LastZone, CurrentAction, CurrentActionMsg

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

function DrawSub(msg, time)
    ClearPrints()
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandPrint(time, 1)
end

function ShowLoadingPromt(msg, time, type)
    CreateThread(function()
        Wait(0)

        BeginTextCommandBusyspinnerOn('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandBusyspinnerOn(type)
        Wait(time)

        BusyspinnerOff()
    end)
end

function GetRandomWalkingNPC()
    local search = {}
    local peds = ESX.Game.GetPeds()

    for i = 1, #peds, 1 do
        if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
            table.insert(search, peds[i])
        end
    end

    if #search > 0 then
        return search[GetRandomIntInRange(1, #search)]
    end

    for i = 1, 250, 1 do
        local ped = GetRandomPedAtCoord(0.0, 0.0, 0.0, math.huge + 0.0, math.huge + 0.0, math.huge + 0.0, 26)

        if DoesEntityExist(ped) and IsPedHuman(ped) and IsPedWalking(ped) and not IsPedAPlayer(ped) then
            table.insert(search, ped)
        end
    end

    if #search > 0 then
        return search[GetRandomIntInRange(1, #search)]
    end
end

function ClearCurrentMission()
    if DoesBlipExist(CurrentCustomerBlip) then
        RemoveBlip(CurrentCustomerBlip)
    end

    if DoesBlipExist(DestinationBlip) then
        RemoveBlip(DestinationBlip)
    end

    CurrentCustomer = nil
    CurrentCustomerBlip = nil
    DestinationBlip = nil
    IsNearCustomer = false
    CustomerIsEnteringVehicle = false
    CustomerEnteredVehicle = false
    targetCoords = nil
end

function StartTaxiJob()
    exports["B1-skillz"]:CheckSkill("Kierowca", 5, function(hasskill)
        if hasskill then
            print('Gracz posiada 5% statystyki : Kierowca')
            ShowLoadingPromt(_U('taking_service'), 5000, 3)
            ClearCurrentMission()
            OnJob = true
        else
            exports['Astro-NotifySystem']:Notify('error', 'Nie masz 5% statystyki kierowcy!')
        end
    end)
end

function StopTaxiJob()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) and CurrentCustomer ~= nil then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(CurrentCustomer, vehicle, 0)

        if CustomerEnteredVehicle then
            TaskGoStraightToCoord(CurrentCustomer, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
        end
    end

    ClearCurrentMission()
    OnJob = false
    exports['Astro-NotifySystem']:Notify('error', 'Skonczyles misje!')
end

function OpenCloakroom()
    lib.registerContext({
        id = 'context:cloakroom',
        title = _U('cloakroom_menu'),
        options = {
            {
                title = _U('wear_citizen'),
                description = 'Stroj roboczy jest potrzebny do pracy!',
                onSelect = function()
                    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                        TriggerEvent('skinchanger:loadSkin', skin)
                    end)
                  end
            },
            {
            title = _U('wear_work'),
            description = 'W swoich ciuchasz czujesz sie najlepiej!',
            onSelect = function()
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
                    if skin.sex == 0 then
                        TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
                    else
                        TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
                    end
                end)
            end
        },
    }
    })
    lib.showContext('context:cloakroom')
end

function OpenVehicleSpawnerMenu()
        lib.registerContext({
            id = 'context:taxipojazd',
            title = 'Moje dokumenty',
            options = {
                {
                    title = 'Wyjmij pojazd',
                    description = 'TAXI',
                    onSelect = function()
                        if not ESX.Game.IsSpawnPointClear(Config.Zones.VehicleSpawnPoint.Pos, 5.0) then
                            ESX.ShowNotification(_U('spawnpoint_blocked'))
                            return
                        end
                        ESX.Game.SpawnVehicle('taxi', Config.Zones.VehicleSpawnPoint.Pos,
                            Config.Zones.VehicleSpawnPoint.Heading, function(vehicle)
                                local playerPed = PlayerPedId()
                                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                            end)
                      end
                },
        }
        })
        lib.showContext('context:taxipojazd')
end

function DeleteJobVehicle()
    local playerPed = PlayerPedId()

        if IsInAuthorizedVehicle() then
            ESX.Game.DeleteVehicle(CurrentActionData.vehicle)

            if Config.MaxInService ~= -1 then
                TriggerServerEvent('esx_service:disableService', 'taxi')
            end
        else
            ESX.ShowNotification(_U('only_taxi'))
        end
    end



    function OpenMobileTaxiActionsMenu()
        lib.registerContext({
            id = 'context:taxi32',
            title = 'Menu glowne',
            options = {
                {
                    title = 'Szukaj klientow',
                    description = 'Rozpocznij wezwania npc!',
                    onSelect = function()
                        if OnJob then
                            StopTaxiJob()
                        else
                            if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.name == 'taxi' then
                                local playerPed = PlayerPedId()
                                local vehicle = GetVehiclePedIsIn(playerPed, false)
            
                                if IsPedInAnyVehicle(playerPed, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                                    if tonumber(ESX.PlayerData.job.grade) >= 3 then
                                        StartTaxiJob()
                                    else
                                        if IsInAuthorizedVehicle() then
                                            StartTaxiJob()
                                        else
                                            ESX.ShowNotification(_U('must_in_taxi'))
                                        end
                                    end
                                else
                                    if tonumber(ESX.PlayerData.job.grade) >= 3 then
                                        ESX.ShowNotification(_U('must_in_vehicle'))
                                    else
                                        ESX.ShowNotification(_U('must_in_taxi'))
                                    end
                                end
                            end
                        end
                      end
                },
                {
                title = 'Faktura',
                description = 'Wystaw graczu fakture!',
                onSelect = function()
                    local input = lib.inputDialog('FAKTURA', {{ type = "number", label = "Jaka kwota?", default = 1, min = '1', max = '2000'}})    
                    local amount = tonumber(input[1])
                    if amount == nil then
                            ESX.ShowNotification(_U('amount_invalid'))
                        else
                            local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                            if closestPlayer == -1 or closestDistance > 3.0 then
                                ESX.ShowNotification(_U('no_players_near'))
                            else
                                TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_taxi', 'Taxi', amount)
                                ESX.ShowNotification(_U('billing_sent'))
                            end
                        end
                        end
            },
        }
        })
        lib.showContext('context:taxi32')
    end

function IsInAuthorizedVehicle()
    local playerPed = PlayerPedId()
    local vehModel = GetEntityModel(GetVehiclePedIsIn(playerPed, false))

    for i = 1, #Config.AuthorizedVehicles, 1 do
        if vehModel == joaat(Config.AuthorizedVehicles[i].model) then
            return true
        end
    end

    return false
end




AddEventHandler('esx_taxijob:hasEnteredMarker', function(zone)
    if zone == 'VehicleSpawner' then
        CurrentAction = 'vehicle_spawner'
        CurrentActionMsg = _U('spawner_prompt')
        CurrentActionData = {}
    elseif zone == 'VehicleDeleter' then
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if IsPedInAnyVehicle(playerPed, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            CurrentAction = 'delete_vehicle'
            CurrentActionMsg = _U('store_veh')
            CurrentActionData = {
                vehicle = vehicle
            }
        end
    end
end)

AddEventHandler('esx_taxijob:hasExitedMarker', function(zone)
    ESX.UI.Menu.CloseAll()
    CurrentAction = nil
end)



-- Create Blips
CreateThread(function()
    local blip = AddBlipForCoord(Config.Zones.TaxiActions.Pos.x, Config.Zones.TaxiActions.Pos.y,
        Config.Zones.TaxiActions.Pos.z)

    SetBlipSprite(blip, 198)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(_U('blip_taxi'))
    EndTextCommandSetBlipName(blip)
end)

-- Enter / Exit marker events, and draw markers
CreateThread(function()
    while true do
        local sleep = 1500
        if ESX.PlayerData.job and ESX.PlayerData.job.name == 'taxi' then

            local coords = GetEntityCoords(PlayerPedId())
            local isInMarker, currentZone = false

            for k, v in pairs(Config.Zones) do
                local zonePos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
                local distance = #(coords - zonePos)

                if v.Type ~= -1 and distance < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Size.x, v.Size.y,
                        v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, false, 2, v.Rotate, nil, nil, false)
                end

                if distance < v.Size.x then
                    isInMarker, currentZone = true, k
                end
            end

            if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
                HasAlreadyEnteredMarker, LastZone = true, currentZone
                TriggerEvent('esx_taxijob:hasEnteredMarker', currentZone)
            end

            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false
                TriggerEvent('esx_taxijob:hasExitedMarker', LastZone)
                lib.hideTextUI()
            end
        end
        Wait(sleep)
    end
end)

-- Taxi Job
CreateThread(function()
    while true do
        local Sleep = 1500

        if OnJob then
            Sleep = 0
            local playerPed = PlayerPedId()
            if CurrentCustomer == nil then
                --DrawSub(_U('drive_search_pass'), 5000)

                if IsPedInAnyVehicle(playerPed, false) and GetEntitySpeed(playerPed) > 0 then
                    local waitUntil = GetGameTimer() + GetRandomIntInRange(30000, 45000)

                    while OnJob and waitUntil > GetGameTimer() do
                        Wait(0)
                    end

                    if OnJob and IsPedInAnyVehicle(playerPed, false) and GetEntitySpeed(playerPed) > 0 then
                        CurrentCustomer = GetRandomWalkingNPC()

                        if CurrentCustomer ~= nil then
                            CurrentCustomerBlip = AddBlipForEntity(CurrentCustomer)

                            SetBlipAsFriendly(CurrentCustomerBlip, true)
                            SetBlipColour(CurrentCustomerBlip, 2)
                            SetBlipCategory(CurrentCustomerBlip, 3)
                            SetBlipRoute(CurrentCustomerBlip, true)

                            SetEntityAsMissionEntity(CurrentCustomer, true, false)
                            ClearPedTasksImmediately(CurrentCustomer)
                            SetBlockingOfNonTemporaryEvents(CurrentCustomer, true)

                            local standTime = GetRandomIntInRange(60000, 180000)
                            TaskStandStill(CurrentCustomer, standTime)

                            ESX.ShowNotification(_U('customer_found'))
                        end
                    end
                end
            else
                if IsPedFatallyInjured(CurrentCustomer) then
                    ESX.ShowNotification(_U('client_unconcious'))

                    if DoesBlipExist(CurrentCustomerBlip) then
                        RemoveBlip(CurrentCustomerBlip)
                    end

                    if DoesBlipExist(DestinationBlip) then
                        RemoveBlip(DestinationBlip)
                    end

                    SetEntityAsMissionEntity(CurrentCustomer, false, true)

                    CurrentCustomer, CurrentCustomerBlip, DestinationBlip, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle, targetCoords =
                        nil, nil, nil, false, false, false, nil
                end

                if IsPedInAnyVehicle(playerPed, false) then
                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                    local playerCoords = GetEntityCoords(playerPed)
                    local customerCoords = GetEntityCoords(CurrentCustomer)
                    local customerDistance = #(playerCoords - customerCoords)

                    if IsPedSittingInVehicle(CurrentCustomer, vehicle) then
                        if CustomerEnteredVehicle then
                            local targetDistance = #(playerCoords - targetCoords)

                            if targetDistance <= 10.0 then
                                TaskLeaveVehicle(CurrentCustomer, vehicle, 0)

                                ESX.ShowNotification(_U('arrive_dest'))

                                TaskGoStraightToCoord(CurrentCustomer, targetCoords.x, targetCoords.y, targetCoords.z,
                                    1.0, -1, 0.0, 0.0)
                                SetEntityAsMissionEntity(CurrentCustomer, false, true)
                                TriggerServerEvent('esx_taxijob:success')
                                RemoveBlip(DestinationBlip)

                                local function scope(customer)
                                    ESX.SetTimeout(60000, function()
                                        DeletePed(customer)
                                    end)
                                end

                                scope(CurrentCustomer)

                                CurrentCustomer, CurrentCustomerBlip, DestinationBlip, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle, targetCoords =
                                    nil, nil, nil, false, false, false, nil
                            end

                            if targetCoords then
                                DrawMarker(36, targetCoords.x, targetCoords.y, targetCoords.z + 1.1, 0.0, 0.0, 0.0, 0.0,
                                    0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)
                            end
                        else
                            RemoveBlip(CurrentCustomerBlip)
                            CurrentCustomerBlip = nil
                            targetCoords = Config.JobLocations[GetRandomIntInRange(1, #Config.JobLocations)]
                            local distance = #(playerCoords - targetCoords)
                            while distance < Config.MinimumDistance do
                                Wait(0)

                                targetCoords = Config.JobLocations[GetRandomIntInRange(1, #Config.JobLocations)]
                                distance = #(playerCoords - targetCoords)
                            end

                            local street = table.pack(GetStreetNameAtCoord(targetCoords.x, targetCoords.y,
                                targetCoords.z))
                            local msg = nil

                            if street[2] ~= 0 and street[2] ~= nil then
                                msg = string.format(_U('take_me_to_near', GetStreetNameFromHashKey(street[1]),
                                    GetStreetNameFromHashKey(street[2])))
                            else
                                msg = string.format(_U('take_me_to', GetStreetNameFromHashKey(street[1])))
                            end

                            ESX.ShowNotification(msg)

                            DestinationBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)

                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentSubstringPlayerName('Destination')
                            EndTextCommandSetBlipName(DestinationBlip)
                            SetBlipRoute(DestinationBlip, true)

                            CustomerEnteredVehicle = true
                        end
                    else
                        DrawMarker(36, customerCoords.x, customerCoords.y, customerCoords.z + 1.1, 0.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)

                        if not CustomerEnteredVehicle then
                            if customerDistance <= 40.0 then

                                if not IsNearCustomer then
                                    ESX.ShowNotification(_U('close_to_client'))
                                    IsNearCustomer = true
                                end

                            end

                            if customerDistance <= 20.0 then
                                if not CustomerIsEnteringVehicle then
                                    ClearPedTasksImmediately(CurrentCustomer)

                                    local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)

                                    for i = maxSeats - 1, 0, -1 do
                                        if IsVehicleSeatFree(vehicle, i) then
                                            freeSeat = i
                                            break
                                        end
                                    end

                                    if freeSeat then
                                        TaskEnterVehicle(CurrentCustomer, vehicle, -1, freeSeat, 2.0, 0)
                                        CustomerIsEnteringVehicle = true
                                    end
                                end
                            end
                        end
                    end
                else
                    --exports['Astro-NotifySystem']:Notify('error', 'Wroc do pojazdu!')  
                end
            end
        end
        Wait(Sleep)
    end
end)

CreateThread(function()
    while OnJob do
        Wait(10000)
        if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.grade < 3 then
            if not IsInAuthorizedVehicle() then
                ClearCurrentMission()
                OnJob = false
                ESX.ShowNotification(_U('not_in_taxi'))
            end
        end
    end
end)

-- Key Controls
CreateThread(function()
    while true do
        local sleep = 1500
        if CurrentAction and not ESX.PlayerData.dead then
            sleep = 0
            lib.showTextUI(CurrentActionMsg)

            if IsControlJustReleased(0, 38) and ESX.PlayerData.job and ESX.PlayerData.job.name == 'taxi' then
                if CurrentAction == 'delete_vehicle' then
                    lib.hideTextUI()
                    DeleteJobVehicle()
                end

                CurrentAction = nil
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('taximenu', function()
    if not ESX.PlayerData.dead and Config.EnablePlayerManagement and ESX.PlayerData.job and ESX.PlayerData.job.name ==
        'taxi' then
        OpenMobileTaxiActionsMenu()
    end
end, false)

RegisterKeyMapping('taximenu', 'Open Taxi Menu', 'keyboard', 'f6')


RegisterNetEvent('taxipojazd', function()
    if ESX.PlayerData.job.name == 'taxi' then
        lib.hideTextUI()
    OpenVehicleSpawnerMenu()
    else
    ESX.ShowNotification('Nie jestes taxowkarzem!')
    end
  end)

  RegisterNetEvent('taxiprzebieralnia', function()
    if ESX.PlayerData.job.name == 'taxi' then
        lib.hideTextUI()
    OpenCloakroom()
    else
    ESX.ShowNotification('Nie jestes taxowkarzem!')
    end
  end)

  RegisterNetEvent('taxischowki', function()
    if ESX.PlayerData.job.name == 'taxi' then
        lib.hideTextUI()
        exports.ox_inventory:openInventory('stash', 'society_taxi')
    else
    ESX.ShowNotification('Nie jestes taxowkarzem!')
    end
  end)

-- targeciki
exports.ox_target:addBoxZone({ -- wyciaganie pojazdow
    coords = vec3(917, -162, 75.0),
    size = vec3(4.0, 5.0, 4.0),
    rotation = 0.0,
    debug = false,
    options = {
        {
            name = 'pojazdtaxi',
            event = 'taxipojazd',
            icon = 'fa-solid fa-taxi',
            label = 'Otworz menu garazu',
        }
    }
})

exports.ox_target:addBoxZone({ -- przebieralnia
    coords = vec3(888.0, -154.0, 77.0),
    size = vec3(2.0, 1.0, 2.0),
    rotation = 120.0,
    debug = false,
    options = {
        {
            name = 'taxiprzebieralnia',
            event = 'taxiprzebieralnia',
            icon = 'fa-solid fa-taxi',
            label = 'Przebierz sie',
        }
    }
})

exports.ox_target:addBoxZone({ -- schowek
    coords = vec3(900.0, -169.5, 74.0),
    size = vec3(1.0, 3.0, 4.0),
    rotation = 30.0,
    debug = false,
    options = {
        {
            name = 'taxischowek',
            event = 'taxischowki',
            icon = 'fa-solid fa-taxi',
            label = 'Otworz schowek',
        }
    }
})