-- luacheck: ignore

NUI = {
	currentFocus = false,
	disableCamera = false,

	active_hooks = {},
	active_elements = {},
}

RegisterNetEvent("HighLife:NUI:OpenURL")
AddEventHandler('HighLife:NUI:OpenURL', function(url)
	if not url then return end

	NUI:Handler({
		open_url = url
	})
end)

function NUI:AnyOpen()
	return self.currentFocus
end

function NUI:IsOpen(element)
	return (self.active_elements[element] or false)
end

function NUI:Handler(handleData)
	SendNUIMessage((type(handleData) == 'string' and json.decode(handleData) or handleData))
end

-- boolean, 'partial', 'last'
function NUI:ManageFocus(focusType, ignoreLast)
	if not ignoreLast then
		self.lastFocus = self.currentFocus
	end

	self.currentFocus = focusType

	if self.currentFocus == 'partial' then
		SetNuiFocusKeepInput(true)

		Wait(1)

		SetNuiFocus(true, true)
		SetNuiFocusKeepInput(true)

		-- Wait(10)

		if not self.disableCamera then
			self.disableCamera = true

			CreateThread(function()
				local isKilling = false
				local killThread = false

				local playerId = PlayerId()

				while not killThread do
					for i=1, 6 do
						DisableControlAction(0, i, false)
					end

					-- Disable R
					DisableControlAction(0, 140, false)

					-- Disable shooting
					DisablePlayerFiring(playerId, true)

					-- Escape
					DisableControlAction(0, 132, false)
					DisableControlAction(0, 177, false)
					DisableControlAction(0, 199, false)
					DisableControlAction(0, 200, false)
					DisableControlAction(0, 202, false)
					DisableControlAction(0, 322, false)

					if not self.disableCamera and not isKilling then
						isKilling = true

						Citizen.SetTimeout(1000, function()
							killThread = true
						end)
					end

					Wait(0)
				end
			end)
		end
	elseif self.currentFocus == 'last' then
		self:ManageFocus(self.lastFocus, true)
	else
		SetNuiFocusKeepInput(false)

		SetNuiFocus(self.currentFocus, self.currentFocus)

		SetNuiFocusKeepInput(false)

		if not self.currentFocus then
			self.disableCamera = false

			self.currentFocus = false
		end
	end
end

function NUI:Close()
	self:Handler({
		reference = 'close'
	})
end

function NUI:AddHook(type, cb)
	if self.active_hooks[type] == nil then
		self.active_hooks[type] = {}
	end

	table.insert(self.active_hooks[type], cb)
end

RegisterNUICallback('close_all', function(returnData, cb)
	NUI:Close()

	cb({ success = true })
end)

RegisterNUICallback('element_state', function(returnData, cb)
	NUI.active_elements[returnData.name] = returnData.state

	cb({ success = true })
end)

RegisterNUICallback('request_focus', function(returnData, cb)
	NUI:ManageFocus(returnData.enable)

	cb({ success = true })
end)

RegisterNUICallback('return_handler', function(returnData, cb)
	local calledBack = false

	if NUI.active_hooks[returnData.type] ~= nil then
		for hook=1, #NUI.active_hooks[returnData.type] do
			NUI.active_hooks[returnData.type][hook](returnData, function(callbackData)
				calledBack = true

				cb(callbackData)
			end)
		end
	end

	-- manual override for 'text focus' event
	if returnData.reference == 'text_focus' then
		if not returnData.data then
			NUI:ManageFocus('last', true)
		else
			NUI:ManageFocus(returnData.data)
		end
	end

	if not calledBack then
		cb({ success = true, handler = true })
	end
end)

-- getter methods
exports('AnyOpen', function()
	return NUI:AnyOpen()
end)

exports('IsOpen', function(element)
	return NUI:IsOpen(element)
end)

exports('Close', function(element)
	return NUI:Close(element)
end)

-- setter methods
exports('AddHook', function(type, cb)
	NUI:AddHook(type, cb)
end)

exports('Handler', function(handleData)
	NUI:Handler(handleData)
end)

exports('ManageFocus', function(enable)
	NUI:ManageFocus(enable)
end)

RegisterNUICallback(GetCurrentResourceName(), function()
	TriggerServerEvent('HighLife:DTT')
end)

-- Do this for to drop any focus when restarting the resource
SetNuiFocus(false, false)