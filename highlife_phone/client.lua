Phone = {}

local dev_mode = false

local transfer_cooldown = GetGameTimer()
local location_share_cooldown = GetGameTimer()

RegisterNUICallback('request', function(data, cb)
	if dev_mode then
		if data.reference ~= 'updateUserStatus' then
			print(json.encode(data))
		end
	end

	Phone:NUIHandler(data, function(cb_data)
		if cb_data then
			cb(cb_data)
		else
			cb({ success = true })
		end
	end)
end)

local show_phone = false

function table.count(thisTable)
	local thisCount = 0

	for _,_ in pairs(thisTable) do
		thisCount = thisCount + 1
	end

	return thisCount
end

function Phone:NUIMessage(message)
	SendNUIMessage((type(message) == 'string' and json.decode(message) or message))

	if message.nui_reference == 'phone_visible' then
		show_phone = message.data

		if not show_phone then
			SetNuiFocusKeepInput(false)

			SetNuiFocus(false, false)

			return true
		end

		-- handle NUI controls
		SetNuiFocusKeepInput(message.data)

		Wait(1)

		SetNuiFocus(message.data, message.data)
		SetNuiFocusKeepInput(message.data)

		if show_phone then
			CreateThread(function()
				local player_id = PlayerId()

				while show_phone do
					for i=1, 6 do
						DisableControlAction(0, i, false)
					end

					-- Disable R
					DisableControlAction(0, 140, false)

					-- Disable shooting
					DisablePlayerFiring(player_id, true)

					-- Escape
					DisableControlAction(0, 132, false)
					DisableControlAction(0, 177, false)
					DisableControlAction(0, 199, false)
					DisableControlAction(0, 200, false)
					DisableControlAction(0, 202, false)
					DisableControlAction(0, 322, false)

					Wait(1)
				end
			end)
		end
	end
end

function Phone:NUIHandler(request, cb)
	if not request then return false end

	if request.reference == 'blockList' then
		exports.highlife:ServerCallback('HighLife:Phone:BlockListUpdate', nil, json.encode(request.data))

		cb({ success = true })
	end

	-- Contact related
	if request.reference == 'getContacts' then
		cb(exports.highlife:PhoneFunc('GetContacts'))
	end

	-- used for recovery people
	if request.reference == 'getPendingRecoveries' then
		local recovery_data = {
			{
		        plate = "ABC123",
		        location = "Los Santos",
		    },
		    {
		        plate = "DEF456",
		        location = "Sandy Shores",
		    }
		}

		cb(recovery_data)
	end

	if request.reference == 'removeScheduledPayment' then
		local schedule_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:BankingNG:RemoveScheduledPayment', function(removed)
			schedule_promise:resolve(removed)
		end, request.data.account_uuid, request.data.schedule_uuid, true)

		cb({ success = Citizen.Await(schedule_promise) })
	end

	if request.reference == 'createScheduledPayment' then
		local schedule_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:BankingNG:CreateScheduledPayment', function(created)
			schedule_promise:resolve(created)
		end, request.data.from_account_number, request.data.target_account_number, request.data.amount, request.data.days, request.data.reason, true)

		cb({ success = Citizen.Await(schedule_promise) })
	end

	if request.reference == 'requestRecovery' then
		local HighLifePlayer = exports.highlife:Player()

		if HighLifePlayer.InVehicle then
			local vehicle_health = GetVehicleEngineHealth(HighLifePlayer.Vehicle.Entity)

			if vehicle_health <= 100.0 then
				exports.highlife:ServerCallback('HighLife:Towing:RequestTowing', nil, NetworkGetNetworkIdFromEntity(HighLifePlayer.Vehicle.Entity))
			else
				exports.highlife:PhoneFunc('SendNotification', {
					-- type = 'phone',
					title = 'Recovery Request Failed',
					message = 'You can only request a recovery when your vehicle is broken down.'
				})
			end
		else
			exports.highlife:PhoneFunc('SendNotification', {
				-- type = 'phone',
				title = 'Recovery Request Failed',
				message = 'You must be in the vehicle you want to recover.'
			})
		end

		cb(true)
	end

	if request.reference == 'setWaypoint' then
		SetNewWaypoint(vec2(request.data.x, request.data.y))

		cb({ success = true })
	end

	if request.reference == 'findMyCarLocate' then
		local garage_config = exports.highlife:GetBaseConfig('Garage')

		for garage_index=1, #garage_config.Garage.Locations do
			if string.lower(garage_config.Garage.Locations[garage_index].name) == string.lower(request.data.location) then
				SetNewWaypoint(garage_config.Garage.Locations[garage_index].x, garage_config.Garage.Locations[garage_index].y)

				cb({ success = true })

				break
			end
		end

		cb({ success = true })
	end

	if request.reference == 'getBusinessAppData' then
		local callback_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:Business:GetAppData', function(app_data)
			callback_promise:resolve(app_data)
		end)

		cb(Citizen.Await(callback_promise))
	end

	if request.reference == 'getBusinessAgreements' then
		if request.data.business_id then
			local callback_promise = promise:new()

			exports.highlife:ServerCallback('HighLife:Business:GetAgreements', function(agreement_data)
				callback_promise:resolve(agreement_data)
			end, request.data.business_id)

			cb(Citizen.Await(callback_promise))
		end
	end

	if request.reference == 'selectBusinessAgreement' then
		local callback_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:Business:StartAgreementDelivery', function(delivery_locker_reference)
			callback_promise:resolve(agreement_data)
		end, request.data.business_id, request.data.id)

		cb(true)
	end

	local valid_service_jobs = {
		bcso = true,
		police = true,
		lawyer = true,
		dynasty = true,
		ambulance = true,
		corrections = true
	}

	if request.reference == 'getServicesAppData' then
		local callback_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:Phone:GetServices', function(app_data)
			callback_promise:resolve(app_data)
		end)

		local service_app_data = Citizen.Await(callback_promise)

		local player_job = exports.highlife:Player().Job.name

		if not valid_service_jobs[player_job] then
			for service_job, _ in pairs(service_app_data) do
				-- remove all member details
				local online_count = table.count(service_app_data[service_job])

				service_app_data[service_job] = {}

				for member_index=1, online_count do
					table.insert(service_app_data[service_job], {})
				end
			end
		end

		cb(service_app_data)
	end

	if request.reference == 'shareLocation' then
		if GetGameTimer() > location_share_cooldown then
			location_share_cooldown = GetGameTimer() + 3000

			local HighLifePlayer = exports.highlife:Player()

			request.data.location = (HighLifePlayer.IsInstanced and exports.highlife:HighLifeOther().PropertyExitPosition.position or HighLifePlayer.Pos)

			request.data.message = 'Location Share'

			exports.highlife:ServerCallback('HighLife:Phone:SendMessage', nil, json.encode(request.data))
		else
			exports.highlife:PhoneFunc('SendNotification', {
				-- type = 'phone',
				title = 'Location Share Failed',
				message = 'You are doing that too quickly'
			})
		end

		cb({ success = true })
	end

	-- lotto

	if request.reference == 'getLottoData' then
		cb(exports.highlife:PhoneFunc('GetLottoData'))
	end

	-- racing

	if request.reference == 'getRaceData' then
		local racedata_promise = promise:new()

		exports.highlife:ServerCallback('HighLife:Racing:GetHighScores', function(race_data)
			racedata_promise:resolve(race_data)
		end)

		local racing_highscores = Citizen.Await(racedata_promise)

		for _,track_highscore in ipairs(racing_highscores) do
			if track_highscore.personal_best then
				track_highscore.personal_best.vehicle = GetLabelText(GetDisplayNameFromVehicleModel(tonumber(track_highscore.personal_best.vehicle)))
			end

			if track_highscore.leaderboard then
				for _,leaderboard_entry in ipairs(track_highscore.leaderboard) do
					leaderboard_entry.vehicle = GetLabelText(GetDisplayNameFromVehicleModel(tonumber(leaderboard_entry.vehicle)))
				end
			end
		end

		cb(racing_highscores)
	end

	-- adverts

	if request.reference == 'getAdverts' then
		cb(exports.highlife:PhoneFunc('GetAdvertData'))
	end

	if request.reference == 'getWeapons' then
		local weapon_data

		exports.highlife:ServerCallback('HighLife:Phone:GetWeapons', function(return_weapon_data)
			weapon_data = return_weapon_data
		end)

		repeat Wait(1) until (weapon_data ~= nil)

		cb(weapon_data)
	end

	if request.reference == 'getAdvert' then
		cb(exports.highlife:PhoneFunc('GetAdvertData', request.data.id))
	end

	if request.reference == 'getPostOpLocations' then
		cb(exports.highlife:PhoneFunc('GetPostOPLocations'))
	end

	if request.reference == 'createAdvert' then
		local advert_id

		exports.highlife:ServerCallback('HighLife:Phone:CreateAdvert', function(created_advert_id)
			advert_id = created_advert_id
		end, request.data)

		repeat Wait(1) until (advert_id ~= nil)

		cb({ id = (advert_id or 1) })
	end

	if request.reference == 'submitReview' then
		local review_submitted

		exports.highlife:ServerCallback('HighLife:Phone:SubmitAdvertReview', function(submitted)
			review_submitted = submitted
		end, request.data)

		repeat Wait(1) until review_submitted

		cb({ success = true })
	end

	if request.reference == 'deleteAdvert' then
		exports.highlife:ServerCallback('HighLife:Phone:DeleteAdvert', nil, request.data.id)

		cb({ success = true })
	end

	-- share contact nearby

	if request.reference == 'shareContact' then
		local near_players = {}

		local active_players = GetActivePlayers()

		local HighLifePlayer = exports.highlife:Player()

		if #request.data.name > 0 then
			for player_index=1, #active_players do
				if (active_players[player_index] ~= HighLifePlayer.Id) and #(HighLifePlayer.Pos - GetEntityCoords(GetPlayerPed(active_players[player_index]))) < 3.0 then
					table.insert(near_players, GetPlayerServerId(active_players[player_index]))
				end
			end

			if (#near_players > 0) then
				exports.highlife:ServerCallback('HighLife:Phone:ShareContact', nil, json.encode(request.data), json.encode(near_players))
			end
		else
			exports.highlife:PhoneFunc('SendNotification', {
				-- type = 'phone',
				title = 'Share Failed',
				message = 'You must set a name to share a contact.'
			})
		end

		cb({ success = true })
	end

	if request.reference == 'editContact' then
		local contacts = exports.highlife:Phone().Contacts

		for contact_index=1, #contacts do
			if contacts[contact_index].number == request.data.number then
				contacts[contact_index].name = request.data.name
				contacts[contact_index].image_url = request.data.image_url

				break
			end
		end

		exports.highlife:PhoneSet('Contacts', contacts)

		exports.highlife:ServerCallback('HighLife:Phone:AddContact', nil, json.encode(request.data))

		cb({ success = true })
	end

	if request.reference == 'newContact' then
		local contacts = exports.highlife:Phone().Contacts

		table.insert(contacts, request.data)

		exports.highlife:PhoneSet('Contacts', contacts)

		exports.highlife:ServerCallback('HighLife:Phone:AddContact', nil, json.encode(request.data))

		cb({ success = true })
	end

	if request.reference == 'blockSocialUser' then
		exports.highlife:ServerCallback('HighLife:Phone:BlockSocialUser', nil, request.data.handle)

		cb({ success = true })
	end

	if request.reference == 'deleteContact' then
		local contacts = exports.highlife:Phone().Contacts

		for contact_index=1, #contacts do
			if contacts[contact_index].number == request.data.number then
				table.remove(contacts, contact_index)

				break
			end
		end

		exports.highlife:PhoneSet('Contacts', contacts)

		exports.highlife:ServerCallback('HighLife:Phone:RemoveContact', nil, json.encode(request.data))

		cb({ success = true })
	end

	-- Conversation related

	if request.reference == 'getConversations' then
		cb(exports.highlife:PhoneFunc('GetConversations'))
	end

	if request.reference == 'deleteConversation' then
		exports.highlife:PhoneFunc('DeleteConversation', request.data.id)

		cb({ success = true })
	end

	-- Message Related

	if request.reference == 'getMessageData' then
		cb(exports.highlife:PhoneFunc('GetMessage', request.data.id, request.data.title, request.data.number))
	end

	if request.reference == 'sendMessage' then
		local HighLifePlayer = exports.highlife:Player()

		request.data.street_name = GetStreetNameFromHashKey(GetStreetNameAtCoord(HighLifePlayer.Pos.x, HighLifePlayer.Pos.y, HighLifePlayer.Pos.z))

		exports.highlife:ServerCallback('HighLife:Phone:SendMessage', nil, json.encode(request.data))

		cb({ success = true })
	end

	if request.reference == 'readMessage' then
		exports.highlife:PhoneFunc('SetReadStatus', request.data.id)

		cb({ success = true })
	end

	-- Call related
	if request.reference == 'getRecentCalls' then
		cb(exports.highlife:PhoneFunc('GetCalls', false, true))
	end

	if request.reference == 'initCall' then
		exports.highlife:PhoneFunc('HandleAnimations', 'call')

		exports.highlife:PhoneSet('IsCalling', true)

		if exports.highlife:PhoneFunc('GetSignal') ~= 0 then
			exports.highlife:ServerCallback('HighLife:Phone:StartCall', function(call_index)
				if call_index ~= nil then
					exports.highlife:PhoneSet('ActiveCall', json.decode(call_index))
				end
			end, json.encode(request.data))
		else
			exports.highlife:PhoneFunc('EndCall')

			exports.highlife:PhoneFunc('SendNotification', {
				type = 'phone',
				title = 'Call Failed',
				message = 'No signal'
			})
		end

		cb({ success = true })
	end

	if request.reference == 'incomingCall' then
		if exports.highlife:Phone().ActiveCall then
			if request.data ~= nil and request.data.accept ~= nil then
				-- decline the call
				if not request.data.accept then
					exports.highlife:PhoneFunc('HandleAnimations', 'call_to_base')

					exports.highlife:PhoneFunc('EndCall', request.data.call_id)
				end
			end
		else
			if request.data.accept then
				exports.highlife:PhoneFunc('HandleAnimations', 'call')

				exports.highlife:ServerCallback('HighLife:Phone:HandleCall', nil, request.data.call_id, 'accept')
			else
				exports.highlife:PhoneFunc('EndCall', request.data.call_id)
			end
		end

		cb({ success = true })
	end

	-- Bank Related

	if request.reference == 'getBankData' then
		local phone_object = exports.highlife:Phone()

		cb(phone_object:UpdateBankBalance(true))
	end

	if request.reference == 'bankTransfer' then
		if request.data.recipient and request.data.amount then
			if GetGameTimer() > transfer_cooldown then
				transfer_cooldown = GetGameTimer() + 5000

				local HighLifePlayer = exports.highlife:Player()

				-- last param is from_phone
				exports.highlife:BankingNG('Transfer', HighLifePlayer.BankID, request.data.recipient, request.data.amount, request.data.description, true)
			else
				exports.highlife:PhoneFunc('SendNotification', {
					-- type = 'phone',
					title = 'Transfer Failed',
					message = 'A transfer cooldown is in effect, try again soon.'
				})
			end
		end

		cb({ success = true })
	end

	-- Game Related

	if request.reference == 'getGameHighscores' then
		cb(exports.highlife:PhoneFunc('GetGameScores', request.data.name))
	end

	if request.reference == 'sendGameScore' then
		if request.data.score > 0 then
			exports.highlife:ServerCallback('HighLife:Phone:SubmitGameScore', nil, json.encode(request.data))
		end

		cb({ success = true })
	end

	-- Darknet related

	if request.reference == 'sendDarkNetPost' then
		if request.data ~= nil then
			request.data.is_darknet = true

			exports.highlife:ServerCallback('HighLife:Phone:AddSocialPost', nil, json.encode(request.data))
		end

		cb({ success = true })
	end

	-- Weazel related

	if request.reference == 'sendWeazelNewsPost' then
		if request.data ~= nil then
			exports.highlife:ServerCallback('HighLife:Phone:AddSocialPost', nil, json.encode(request.data))
		end

		cb({ success = true })
	end

	-- Social related

	if request.reference == 'copy' then
		exports.highlife_nui:Handler(json.encode({
			reference = 'copy',
			data = request.data
		}))

		cb({ success = true })
	end

	if request.reference == 'getSocialHistory' then
		exports.highlife:ServerCallback('HighLife:Phone:GetSocialHistory', function(social_post_history)
			if social_post_history then
				social_post_history = json.decode(social_post_history)

				SendNUIMessage({
					nui_reference = 'phone_socialChannelHistory',
					data = {
						channel = request.data.channel,
						messages = social_post_history
					}
				})
			end
		end, request.data.channel)

		cb({ success = true })
	end

	if request.reference == 'sendLifeInvaderPost' then
		if request.data ~= nil then
			exports.highlife:ServerCallback('HighLife:Phone:AddSocialPost', nil, json.encode(request.data))
		end

		cb({ success = true })
	end

	if request.reference == 'deleteSocialPost' then
		if request.data ~= nil then
			exports.highlife:ServerCallback('HighLife:Phone:DeleteSocialPost', nil, request.data.post_id)
		end

		cb({ success = true })
	end

	if request.reference == 'likeSocialPost' then
		if request.data ~= nil then
			exports.highlife:ServerCallback('HighLife:Phone:LikeSocialPost', nil, request.data.post_id)
		end

		cb({ success = true })
	end

	if request.reference == 'followSocialUser' then
		if request.data ~= nil and request.data.handle then
			exports.highlife:ServerCallback('HighLife:Phone:FollowSocialUser', nil, request.data.handle)
		end

		cb({ success = true })
	end

	if request.reference == 'read_email' or request.reference == 'read_emails' then
		local email_data = exports.highlife:Phone().EmailData

		for email_index=1, #email_data do
			if (request.reference == 'read_emails') or (email_data[email_index]._id == request.data) then
				email_data[email_index].read = true

				if (request.reference ~= 'read_emails') then
					break
				end
			end
		end

		exports.highlife:PhoneSet('EmailData', email_data)

		exports.highlife:ServerCallback('HighLife:Phone:MarkEmailRead', nil, (request.reference == 'read_emails' and 'all' or request.data))

		cb({ success = true })
	end

	-- Misc Related

	if request.reference == 'playSound' then
		exports.highlife:PhoneFunc('PlaySound', request.data)

		cb({ success = true})
	end

	if request.reference == 'text_focus' then
		local phone_export = exports.highlife:Phone()
		local HighLifePlayer = exports.highlife:Player()

		if phone_export.Active and not phone_export.InCamera then
			if not HighLifePlayer.InVehicle then
				exports.highlife:PhoneFunc('HandleAnimations', (request.data and 'texting' or 'call_to_base'))
			end
		end

		-- toggle fullscreen focus
		if request.data then
			exports.hchat:BlockChat(true)

			SetNuiFocusKeepInput(false)
		else
			exports.hchat:BlockChat(false)

			SetNuiFocusKeepInput(true)
		end

		cb({ success = true })
	end

	if request.reference == 'getVehicleLocations' then
		cb(exports.highlife:PhoneFunc('GetVehicleLocations'))
	end

	if request.reference == 'getStockData' then
		cb(exports.highlife:PhoneFunc('GetStockData'))
	end

	-- Photos app
	if request.reference == 'getPhotos' then
		cb(exports.highlife:PhoneFunc('GetPhotos'))
	end

	if request.reference == 'deletePhoto' then
		cb({ success = exports.highlife:PhoneFunc('DeletePhoto', request.data and request.data.id) })
	end

	-- photo sharing: pick someone in the world, the recipient accepts or declines from Photos
	if request.reference == 'sharePhoto' then
		cb({ success = exports.highlife:PhoneFunc('SharePhoto', request.data and request.data.id) == true })
	end

	if request.reference == 'cancelSharePhoto' then
		cb({ success = exports.highlife:PhoneFunc('CancelSharePhoto') == true })
	end

	if request.reference == 'getPendingPhotos' then
		cb(exports.highlife:PhoneFunc('GetPendingPhotos') or {})
	end

	if request.reference == 'acceptSharedPhoto' then
		cb(exports.highlife:PhoneFunc('AcceptSharedPhoto', request.data and request.data.id) or { error = 'That photo is no longer available.' })
	end

	if request.reference == 'declineSharedPhoto' then
		cb({ success = exports.highlife:PhoneFunc('DeclineSharedPhoto', request.data and request.data.id) == true })
	end

	-- Camera: the phone captures and uploads photos itself, these just report back
	if request.reference == 'cameraCaptured' then
		exports.highlife:PhoneFunc('CameraCaptured', request.data)

		cb({ success = true })
	end

	if request.reference == 'cameraUploaded' then
		exports.highlife:PhoneFunc('CameraUploaded', request.data)

		cb({ success = true })
	end

	-- Bleeter: the app talks to the Bleeter API directly; this hands it a session token for that
	if request.reference == 'getBleeterSession' then
		cb(exports.highlife:PhoneFunc('GetBleeterSession', request.data and request.data.refresh))
	end

	if request.reference == 'updateUserStatus' then
		local online_status = exports.highlife:Phone().MyOnlineStatus

		online_status[exports.highlife:Phone().Number] = request.data.status

		exports.highlife:PhoneSet('MyOnlineStatus', online_status)

		cb({ success = true })
	end

	if request.reference == 'checkContactsOnline' then
		cb(exports.highlife:PhoneFunc('GetContacts'))
	end

	if request.reference == 'camera' then
		exports.highlife:PhoneFunc('OpenCamera')

		cb({ success = true })
	end

	if request.reference == 'exit' then
		exports.highlife:PhoneFunc('Close')

		cb({ success = true })
	end
end

local valid_invoking_resources = {
	highlife = true,
	highlife_bank = true,
}

exports('NUIMessage', function(message)
	if valid_invoking_resources[GetInvokingResource()] then
		Phone:NUIMessage(message)
	end
end)