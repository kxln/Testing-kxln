Storage = {}

local valid_invoking_resources = {
	highlife = true,
	highlife_storage = true,
}

-- HELPER FUNCS

function string.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end

	local t={} ; i=1

	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end

	return t
end

function table.count(test_table)
	local key_count = 0

	for _,_ in pairs(test_table) do
		key_count = key_count + 1
	end

	return key_count
end

-- GAME -> NUI

-- set the metadata for the inventory UI to use
function Storage:SetMetadata(item_weights, use_dialogues, item_names, visible_attributes, visible_attribute_prefixes, visible_attribute_suffixes, is_dev)
	self.IsDev = is_dev

	SendNUIMessage({
		reference = 'set_metadata',
		data = {
			weights = (item_weights or {}),
			use_dialog = (use_dialogues or {}),
			item_names = (item_names or {}),
			visible_attributes = (visible_attributes or {}),
			visible_attribute_prefixes = (visible_attribute_prefixes or {}),
			visible_attribute_suffixes = (visible_attribute_suffixes or {}),
		}
	})

	return true
end

function Storage:SetFavorData(favor_data)
	if not favor_data then return false end

	SendNUIMessage({
		reference = 'set_favors',
		data = favor_data
	})
end

function Storage:SetDailyAcitivities(activities_data, allow_illegal_tasks, end_time)
	if not activities_data then return false end

	SendNUIMessage({
		reference = 'set_daily_activities',
		data = activities_data,
		allow_illegal_tasks = allow_illegal_tasks,
		end_time = (end_time * 1000.0)
	})
end

-- open the inventory for the client
function Storage:ShowInventory(state, specific_tab, favor_name, disable_moving, name, type)
	self.InventoryVisible = state

	if not self.InventoryVisible then
		self.OpenStorageIsContainer = nil
	end

	if self.InventoryVisible then
		SetNuiFocusKeepInput((not disable_moving))

		Wait(1)

		SetNuiFocus(true, true)

		if not disable_moving then
			SetNuiFocusKeepInput((not disable_moving))
		end

		CreateThread(function()
			while self.InventoryVisible do
				DisablePlayerFiring(PlayerId(), true)

				-- left click
				DisableControlAction(0, 24, true)
				-- right click
				DisableControlAction(0, 25, true)
				DisableControlAction(0, 50, true)

				DisableControlAction(0, 68, true)
				DisableControlAction(0, 69, true)
				DisableControlAction(0, 70, true)

				DisableControlAction(0, 91, true)
				DisableControlAction(0, 92, true)

				for i=1, 6 do
					-- camera controls
					DisableControlAction(0, i, true)
				end

				Wait(1)
			end
		end)
	else
		DisablePlayerFiring(PlayerId(), false)

		CreateThread(function()
			local end_timeout = GetGameTimer() + 500

			while GetGameTimer() < end_timeout do
				DisableControlAction(0, 177, true)
				DisableControlAction(0, 200, true)
				DisableControlAction(0, 202, true)
				DisableControlAction(0, 322, true)

				Wait(1)
			end
		end)

		SetNuiFocus(false, false)
		SetNuiFocusKeepInput(false)
	end

	-- specific_tab = (daily-activities/favors)

	SendNUIMessage({
		reference = 'inventory_visible',
		data = {
			visible = self.InventoryVisible,
			tab = specific_tab,
			favor_name = favor_name,
			name = name,
			type = type
		}
	})

	return true
end

-- sets the current user inventory
function Storage:SetInventory(inventory_storage_data)
	self.InventoryData = inventory_storage_data

	-- out inventory has been set, do we still have our open storage container item?
	if self.OpenStorageIsContainer then
		local has_container = false

		for _,item_data in ipairs(self.InventoryData.items) do
			if item_data.g_id and (string.format('container_%s', item_data.g_id) == self.OpenStorageReference) then
				has_container = true

				if item_data.attributes.container_locked then
					has_container = false
				end

				break
			end
		end

		if not has_container then
			-- we no longer have the container open, close the storage
			self:CloseStorage(false)
		end
	end

	SendNUIMessage({
		reference = 'set_inventory',
		data = self.InventoryData
	})

	if self.IsDev then
		-- print('set inventory', json.encode(self.InventoryData))
	end

	return true
end

function Storage:FindItemData(item_id)
	if not item_id then return false end

	for _,item_data in ipairs(self.InventoryData.items) do
		if item_data.g_id == item_id then
			return item_data
		end
	end

	if not self.OpenStorageData then return false end

	for _,item_data in ipairs(self.OpenStorageData.items) do
		if item_data.g_id == item_id then
			return item_data
		end
	end

	return false
end

-- shows a storage with the given data, this will open the inventory
function Storage:ShowStorage(storage_data, is_update)
	local disable_moving = false

	local is_robbery_storage_type = (storage_data.type == 'robbery')

	if is_robbery_storage_type then
		disable_moving = true
	end

	-- got a storage update, not opening though as is update and open reference mismatch
	if is_update and (storage_data.storage_reference ~= self.OpenStorageReference) then return false end

	self:ShowInventory(true, nil, nil, disable_moving)

	if storage_data then
		-- save the deposit only state if it's been updated
		if self.OpenStorageReference ~= storage_data.storage_reference then
			self.OpenStorageDepositOnly = storage_data.deposit_only
		end

		self.OpenStorageData = storage_data
		self.OpenStorageReference = storage_data.storage_reference

		if string.find(self.OpenStorageReference, 'container') then
			self.OpenStorageIsContainer = true
		end

		if self.IsDev then
			print('set storage', self.OpenStorageReference, json.encode(storage_data))
		end

		SendNUIMessage({
			reference = 'set_storage',
			data = storage_data
		})

		return true
	end

	return false
end

-- close any open storage, optionally close the inventory
function Storage:CloseStorage(close_inventory)
	if close_inventory then
		self:ShowInventory(false)
	end

	self.OpenStorageIsContainer = nil

	exports.highlife:CloseStorage()

	-- tell the server we're no longer viewing the storage
	self:RemoveViewingStorage()

	SendNUIMessage({
		reference = 'close_storage',
		data = storage_data
	})

	return true
end

-- sets the current ordering to the UI
function Storage:SetStorageOrdering(storage_reference, storage_ordering)
	SendNUIMessage({
		reference = 'set_storage_ordering',
		storage_reference = storage_reference,
		ordering = storage_ordering
	})

	return true
end

-- select the hotbar item from the UI
function Storage:SelectHotbarIndex(hotbar_index)
	if self.InventoryVisible then return false end

	hotbar_index = (hotbar_index - 1)

	SendNUIMessage({
		reference = 'hotbar_select',
		data = hotbar_index
	})

	return true
end

function Storage:ControllerAction(action_index)
	if not self.InventoryVisible then return false end

	SendNUIMessage({
		reference = 'controller_action',
		data = action_index
	})

	return true
end

-- notify the user within the UI
function Storage:Notification(message)
	if not self:IsInventoryVisible() then
		-- send the notif via the main UI
		exports.highlife:Notification_AboveMap(message)

		return true
	end

	SendNUIMessage({
		reference = 'notification',
		message = message
	})

	return true
end

function Storage:BusinessNotification(notification_data)
	if type(notification_data) ~= 'table' or not notification_data.message then return false end

	SendNUIMessage({
		reference = 'business_notification',
		data = notification_data
	})

	return true
end

function Storage:PushNUIMessage(data)
	if not data then return false end

	SendNUIMessage(data)

	return true
end

-- GAME -> NUI END

-- NUI -> GAME

function Storage:IsInventoryVisible()
	return self.InventoryVisible
end

function Storage:GetOpenStorage()
	return self.OpenStorageReference
end

function Storage:RemoveViewingStorage()
	if not self.OpenStorageReference then return false end

	exports.highlife:ServerCallback('HighLife:StorageNG:RemoveViewingStorage')

	self.OpenStorageData = nil
	self.OpenStorageReference = nil

	return true
end

function Storage:IsDepositOnly(storage_reference)
	return (self.OpenStorageDepositOnly and (storage_reference == self.OpenStorageReference))
end

function Storage:IsContainer(item_id)
	if (not item_id) then return false end

	for _,item_data in ipairs(self.InventoryData.items) do
		if item_data.g_id == item_id then
			return item_data.attributes.is_container
		end
	end

	return false
end

-- uses an item if possible to
function Storage:UseItem(item_id, storage_reference)
	if (not item_id) or (not storage_reference) then return false end

	if self:IsContainer(item_id) then
		self:OpenItem(item_id)

		return false
	end

	local has_item = false

	local is_quick_use_item = false

	-- is item a weapon, if so 'use it' differently
	for _,item_data in ipairs(self.InventoryData.items) do
		if item_data.g_id == item_id then
			has_item = true

			is_quick_use_item = exports.highlife:IsQuickUseItem(item_data.name)

			if item_data.attributes then
				-- it's a weapon, get it out
				if item_data.attributes.weapon then
					exports.highlife:HandleUseWeapon(item_id)

					return true
				end

				-- it's a book, show it
				if item_data.attributes.is_book then
					-- it has images to show
					exports.highlife:OpenBook(item_data.g_id, item_data.name)

					return true
				end
			end
		end
	end

	if not has_item then return false end

	local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

	if active_weapon_id and (active_weapon_id ~= item_id) and (not is_quick_use_item) then
		self:Notification("Holster the weapon first.")

		return false
	end

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:UseItem', function(success, close_inventory)
		if close_inventory then
			-- close the ui if we can use the item
			exports.highlife:CloseInventory()
		end

		p:resolve(success)
	end, item_id, storage_reference)

	return Citizen.Await(p)
end

-- opens an item which is a container
function Storage:OpenItem(item_id)
	if (not item_id) then return false end

	local can_access_item = false

	-- do we have item_id in our self.InventoryData?
	for _,item_data in ipairs(self.InventoryData.items) do
		if item_data.g_id == item_id then
			can_access_item = true

			if item_data.attributes.container_locked then
				self:Notification("This container is locked.")

				return false
			end

			break
		end
	end

	if not can_access_item then return false end

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:Get', function(storage_data)
		if storage_data then
			-- if exists, open the storage for the item, typically a container
			self:ShowStorage(storage_data)
		end

		-- even if this fails, we'll still return true to the UI, which is fine
		p:resolve(true)
	end, string.format('container_%s', item_id), 'container')

	return Citizen.Await(p)
end

function Storage:DropItem(item_id, storage_reference, desired_ordering)
	if (not item_id) or (not storage_reference) then return false end

	local p = promise.new()

	p:resolve(exports.highlife:DropInventoryItem(item_id, storage_reference, desired_ordering))

	return Citizen.Await(p)
end

function Storage:PlaceItem(item_id, storage_reference, desired_ordering)
	if (not item_id) or (not storage_reference) then return false end

	exports.highlife:PlaceInventoryItem(item_id, storage_reference, desired_ordering)

	exports.highlife:CloseInventory()

	return true
end

function Storage:GiveItem(item_id, storage_reference)
	if (not item_id) or (not storage_reference) then return false end

	exports.highlife:StorageGiveItem(item_id, storage_reference)

	-- close the inventory, allow the prompt stuff for allowing transfer
	exports.highlife:CloseInventory()

	return true
end

-- moves an item between two storages
function Storage:MoveItem(item_id, storage_reference, target_storage_reference, desired_ordering, store_location_reference, is_quick_action)
	if (not item_id) or (not storage_reference) or (not target_storage_reference) then return false end

	local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

	if active_weapon_id and (active_weapon_id == item_id) then
		self:Notification("Holster the weapon first.")

		return false
	end

	local item_data = self:FindItemData(item_id)

	if not item_data then return false end

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:MoveItem', function(success)
		p:resolve(success)
	end, item_id, (item_data._v_move or 0), storage_reference, target_storage_reference, desired_ordering, store_location_reference, is_quick_action)

	return Citizen.Await(p)
end

-- splits an item in a storage
function Storage:SplitItem(item_id, split_amount, storage_reference)
	if (not item_id) or (not split_amount) or (not storage_reference) then return false end

	if (not tonumber(split_amount)) or (split_amount < 0) then return false end

	split_amount = math.floor(tonumber(split_amount))

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:SplitItem', function(success)
		p:resolve(success)
	end, item_id, split_amount, storage_reference)

	return Citizen.Await(p)
end

-- attempts to merge an item in a storage, or between two storages
-- if this returns false, just swap the positions of the items
function Storage:MergeItem(item_id, target_item_id, storage_reference, target_storage_reference, desired_ordering, store_location_reference)
	if (not item_id) or (not target_item_id) or (not storage_reference) then return false end

	local extra_merge_params = {}

	-- find the item_id either in our local storage or the openstorage
	local merge_item_data = self:FindItemData(item_id)

	if merge_item_data then
		-- is it a weapon_mod?
		if merge_item_data.attributes.is_weapon_mod then
			-- local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

			-- if active_weapon_id and (active_weapon_id == target_item_id) then
			-- 	self:Notification("Holster the weapon first.")

			-- 	return false
			-- end

			-- okay, does this fit on our target item?
			local target_item_data = self:FindItemData(target_item_id)

			-- if it exists, ensure it's a weapon
			if target_item_data and target_item_data.attributes.weapon then
				local found_valid_component = exports.highlife:GetWeaponModComponentName(merge_item_data.name, target_item_data.name)

				if found_valid_component then
					extra_merge_params.weapon_component = found_valid_component
				end
			end
		end
	end

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:MergeItem', function(success)
		p:resolve(success)
	end, item_id, target_item_id, storage_reference, target_storage_reference, extra_merge_params, desired_ordering, store_location_reference)

	return Citizen.Await(p)
end

function Storage:RemoveWeaponAttachment(item_id, storage_reference, attachment_name)
	if (not item_id) or (not storage_reference) then return false end

	local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

	local p = promise:new()

	exports.highlife:ServerCallback('HighLife:StorageNG:RemoveWeaponAttachment', function(success)
		if success then
			-- remove the attachment from the weapon if active
			if active_weapon_id then
				local weapon_item_data = self:FindItemData(active_weapon_id)

				local attachment_hash = weapon_item_data.attributes.weapon.attachments[attachment_name]

				if attachment_hash then
					RemoveWeaponComponentFromPed(PlayerPedId(), GetHashKey(weapon_item_data.name), attachment_hash)
				end
			end
		end

		p:resolve(success)
	end, item_id, storage_reference, attachment_name)

	return Citizen.Await(p)
end

function Storage:HandleStorageAction(storage_reference, action)
	if (not storage_reference) or (not action) then return false end

	if self.ActionCooldown and (GetGameTimer() < self.ActionCooldown) then return false end

	self.ActionCooldown = (GetGameTimer() + 2000)

	local p = promise:new()

	exports.highlife:ServerCallback('HighLife:StorageNG:HandleStorageAction', function(success)
		p:resolve(success)
	end, storage_reference, action)

	return Citizen.Await(p)
end

function Storage:HandleMiscItemActions(item_id, storage_reference, item_action)
	if (not item_id) or (not storage_reference) or (not item_action) then return false end

	local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

	if active_weapon_id and (active_weapon_id == item_id) then
		self:Notification("Holster the weapon first.")

		return false
	end

	-- remove the last _item part if exists
	item_action = item_action:sub(1, -6)

	local action_data = {}

	if item_action == 'show_id' then
		-- get near players, if there are any
		local our_player_id = PlayerId()
		local our_player_position = GetEntityCoords(PlayerPedId())

		for _, player_id in ipairs(GetActivePlayers()) do
			if (player_id ~= our_player_id) then
				local ped = GetPlayerPed(player_id)

				local distance = #(our_player_position - GetEntityCoords(ped))

				if distance < 2.5 then
					if not action_data.target_players then
						action_data.target_players = {}
					end

					table.insert(action_data.target_players, GetPlayerServerId(player_id))
				end
			end
		end

		if not action_data.target_players then
			self:Notification("Nobody nearby to show the ID to.")

			return false
		end
	end

	local p = promise:new()

	exports.highlife:ServerCallback('HighLife:StorageNG:HandleItemAction', function(success)
		p:resolve(success)
	end, item_id, storage_reference, item_action, action_data)

	return Citizen.Await(p)
end

-- updates the storage ordering for a storage reference on the server
function Storage:SetServerStorageOrdering(storage_reference, storage_ordering)
	if (not storage_reference) or (not storage_ordering) then return false end

	PlaySoundFrontend(-1, "Score_Opponent", "DLC_Biker_KQ_Sounds")

	if self.IsDev then
		print('set server ordering', storage_reference, json.encode(storage_ordering))
	end

	exports.highlife:SetInventoryLocalOrdering(storage_reference, storage_ordering)

	local p = promise.new()

	exports.highlife:ServerCallback('HighLife:StorageNG:SetStorageOrdering', function(success)
		p:resolve(success)
	end, storage_reference, storage_ordering)

	return Citizen.Await(p)
end

-- CRAFTING

function Storage:IsValidCraft(crafting_data)
	if not crafting_data then return false end

	return exports.highlife:IsValidCraft(crafting_data)
end

function Storage:CraftItem(crafting_data)
	if not crafting_data then return false end

	return exports.highlife:CraftItem(crafting_data)
end

-- CRAFTING CALLBACKS

RegisterNUICallback('check_craft', function(data, cb)
	cb(Storage:IsValidCraft(data))
end)

RegisterNUICallback('craft_item', function(data, cb)
	cb(Storage:CraftItem(data))
end)

-- recipe books on the crafting and refiner tabs (crafting is paged, there are 1500+ recipes)
RegisterNUICallback('get_crafting_recipes', function(data, cb)
	cb(exports.highlife:GetRecipeBook(data) or {})
end)

-- the cooking tab (client/core/cooking.lua in highlife)
RegisterNUICallback('cook_action', function(data, cb)
	cb(exports.highlife:CookAction(data) or { success = false })
end)

RegisterNUICallback('get_refining_recipes', function(data, cb)
	cb(exports.highlife:GetRefiningBook() or {})
end)

-- BUSINESS CALLBACKS

RegisterNUICallback('create_business', function(data, cb)
	cb(exports.highlife:BusinessObject():Create(data))
end)

RegisterNUICallback('get_business_create_info', function(data, cb)
	cb(exports.highlife:BusinessObject():GetCreateInfo() or {})
end)

RegisterNUICallback('set_business', function(data, cb)
	print('set_business', json.encode(data))

	cb({})
end)

RegisterNUICallback('get_businesses', function(data, cb)
	local business_data = exports.highlife:BusinessObject():GetUIBusinesses()

	cb(business_data)
end)

RegisterNUICallback('get_business_page', function(data, cb)
	local business_page_data = exports.highlife:BusinessObject():GetUIPage(data.business_id, data.page)

	cb(business_page_data)
end)

RegisterNUICallback('business_event', function(data, cb)
	exports.highlife:BusinessObject():ProcessEvent(data)

	cb(true)
end)

-- NUI -> GAME END

-- CALLBACKS BEGIN

RegisterNUICallback('close_inventory', function(data, cb)
	Storage:ShowInventory(false)

	-- ensure to close the storage too
	Storage:CloseStorage()

	exports.highlife:CloseInventory()

	cb({ success = true })
end)

RegisterNUICallback('close_storage', function(data, cb)
	Storage:CloseStorage()

	cb({ success = true })
end)

RegisterNUICallback('set_storage_ordering', function(data, cb)
	local action_processed = Storage:SetServerStorageOrdering(data.storage_reference, data.storage_ordering)

	cb({ success = action_processed })
end)

RegisterNUICallback('get_active_weapon', function(data, cb)
	local active_weapon_id = exports.highlife:GetStorageActiveWeaponId()

	cb({ active_weapon_id = active_weapon_id })
end)

RegisterNUICallback('purchase_wholesale_items', function(data, cb)
	cb(exports.highlife:BusinessObject():PurchaseWholesaleItems(data.business_id, data.items, data.delivery_location_reference))
end)

RegisterNUICallback('get_wholesale_types', function(data, cb)
	cb(exports.highlife:BusinessObject():GetBusinessWholesaleTypes(data.business_id))
end)

RegisterNUICallback('get_business_delivery_locations', function(data, cb)
	cb(exports.highlife:BusinessObject():GetDeliveryLocations(data.business_id))
end)

RegisterNUICallback('get_agreements', function(data, cb)
	cb(exports.highlife:BusinessObject():GetAgreements(data.business_id))
end)

RegisterNUICallback('create_agreement', function(data, cb)
	cb(exports.highlife:BusinessObject():CreateAgreement(data.business_id, data.item, data.amount, data.price, data.delivery_location_reference))
end)

RegisterNUICallback('cancel_agreement', function(data, cb)
	cb(exports.highlife:BusinessObject():CancelAgreement(data.business_id, data.id))
end)

RegisterNUICallback('search_agreement_items', function(data, cb)
	cb(exports.highlife:BusinessObject():SearchAgreementItems(data.query))
end)

RegisterNUICallback('inventory_action', function(data, cb)
	local success = false

	if Storage.IsDev then
		print(json.encode(data))
	end

	Storage:HandleStorageAction(data.storage_reference, data.action)

	cb({ success = success })
end)

RegisterNUICallback('has_focus', function(data, cb)
	SetNuiFocusKeepInput((not data.focus))

	cb({ success = true})
end)

RegisterNUICallback('item_action', function(data, cb)
	local success = false

	if Storage.IsDev then
		print(json.encode(data))
	end

	local found_action = false

	-- if the storage is deposit only and it's the open storage, reject any non-move actions
	if Storage:IsDepositOnly(data.storage_reference) then
		cb({ success = false })

		return false
	end

	local store_location_reference = nil

	if Storage.OpenStorageData and Storage.OpenStorageData.attributes and Storage.OpenStorageData.attributes.store_location then
		store_location_reference = Storage.OpenStorageData.attributes.store_location
	end

	if data.action == 'use_item' then
		success = Storage:UseItem(data.item_id, data.storage_reference)

		found_action = true
	elseif data.action == 'open_item' then
		success = Storage:OpenItem(data.item_id, data.storage_reference)

		found_action = true
	elseif data.action == 'drop_item' then
		success = Storage:DropItem(data.item_id, data.storage_reference, data.desired_ordering)

		found_action = true
	elseif data.action == 'place_item' then
		success = Storage:PlaceItem(data.item_id, data.storage_reference, data.desired_ordering)

		found_action = true
	elseif data.action == 'give_item' then
		success = Storage:GiveItem(data.item_id, data.storage_reference)

		found_action = true
	elseif data.action == 'move_item' then
		success = Storage:MoveItem(data.item_id, data.storage_reference, data.target_storage_reference, data.desired_ordering, store_location_reference, data.quick_action)

		found_action = true
	elseif data.action == 'split_item' then
		success = Storage:SplitItem(data.item_id, data.split_amount, data.storage_reference)

		found_action = true
	elseif data.action == 'merge_items' then
		success = Storage:MergeItem(data.item_id, data.target_item_id, data.storage_reference, data.target_storage_reference, data.desired_ordering, store_location_reference)

		found_action = true
	elseif data.action == 'remove_weapon_attachment' then
		success = Storage:RemoveWeaponAttachment(data.item_id, data.storage_reference, data.attachment_name)

		found_action = true
	end

	if not found_action then
		success = Storage:HandleMiscItemActions(data.item_id, data.storage_reference, data.action)
	end

	cb({ success = success })
end)

-- CALLBACKS END

-- EXPORTS BEGIN

exports('SetMetadata', function(...)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SetMetadata(...)
end)

exports('ShowInventory', function(state, specific_tab, favor_name, disable_moving, name, type)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:ShowInventory(state, specific_tab, favor_name, disable_moving, name, type)
end)

exports('CloseStorage', function()
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:CloseStorage(close_inventory)
end)

exports('SetInventory', function(inventory_storage_data)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SetInventory(inventory_storage_data)
end)

exports('ShowStorage', function(storage_data, is_update)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:ShowStorage(storage_data, is_update)
end)

exports('SetStorageOrdering', function(storage_reference, storage_ordering)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SetStorageOrdering(storage_reference, storage_ordering)
end)

exports('SetFavorData', function(favor_data)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SetFavorData(favor_data)
end)

exports('SetDailyAcitivities', function(favor_data, allow_illegal_tasks, end_time)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SetDailyAcitivities(favor_data, allow_illegal_tasks, end_time)
end)

exports('Notification', function(message)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:Notification(message)
end)

exports('SelectHotbarIndex', function(hotbar_index)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:SelectHotbarIndex(hotbar_index)
end)

exports('ControllerAction', function(action_index)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	Storage:ControllerAction(action_index)
end)

exports('GetOpenStorage', function()
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	return Storage:GetOpenStorage()
end)

exports('IsInventoryVisible', function()
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	return Storage:IsInventoryVisible()
end)

exports('SetBusinessPage', function(page_data)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	SendNUIMessage({
		reference = 'set_business_page',
		data = page_data
	})
end)

exports('BusinessNotification', function(notification_data)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	return Storage:BusinessNotification(notification_data)
end)

exports('PushNUIMessage', function(message_data)
	if not valid_invoking_resources[GetInvokingResource()] then return false end

	return Storage:PushNUIMessage(message_data)
end)

-- EXPORTS END
