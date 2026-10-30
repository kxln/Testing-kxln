Bank = {
	IsOpen = false
}

function Bank:Setup(name, player_reference)
	SendNUIMessage({
		reference = 'set_player',
		data = {
			name = name,
			id = player_reference
		}
	})
end

function Bank:Update(account_uuid, account_data, transaction_row)
	SendNUIMessage({
		reference = 'update_account',
		data = {
			account_uuid = account_uuid,
			account_data = account_data,
			transaction_row = transaction_row
		}
	})
end

-- the player lost access to an account (e.g. their business rank changed)
function Bank:Revoke(account_uuid)
	SendNUIMessage({
		reference = 'revoke_account',
		data = {
			account_uuid = account_uuid
		}
	})
end

function Bank:Notification(message)
	SendNUIMessage({
		reference = 'notification',
		data = {
			message = message
		}
	})
end

function Bank:Visible(status, is_atm)
	self.IsOpen = status

	SetNuiFocus(self.IsOpen, self.IsOpen)

	SendNUIMessage({
		reference = 'set_visible',
		data = {
			is_atm = is_atm,
			visible = self.IsOpen
		}
	})
end

RegisterNUICallback('has_focus', function(data, cb)
	SetNuiFocusKeepInput((not data.focus))

	cb({ success = true })
end)

RegisterNUICallback('close', function(data, cb)
	Bank:Visible(false)

	exports.highlife:CloseBank()

	cb({ success = true })
end)

RegisterNUICallback('handler', function(data, cb)
	local success = exports.highlife:BankingNG(data.event, table.unpack(data.args or {}))

	cb(success)
end)

exports('Visible', function(visible, is_atm)
	Bank:Visible(visible, is_atm)
end)

exports('Setup', function(name, player_reference)
	Bank:Setup(name, player_reference)
end)

exports('Update', function(account_uuid, account_data, transaction_row)
	Bank:Update(account_uuid, account_data, transaction_row)
end)

exports('Notification', function(message)
	Bank:Notification(message)
end)

exports('Revoke', function(account_uuid)
	Bank:Revoke(account_uuid)
end)