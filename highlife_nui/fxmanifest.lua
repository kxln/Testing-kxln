fx_version 'cerulean'

games { 'gta5', 'gta5enhanced' }

name 'highlife_nui'

author 'Jarrrk x Kissane'

nui_callback_strict_mode 'false'

files {
	'html/**/*.*',
	'html/index.html'
}

lua54 'yes'

ui_page 'html/index.html'
-- ui_page 'https://cdn.highliferoleplay.net/build/nui/html/?static=true'

client_scripts {
	'three.js',
	'nui_handler.lua'
}