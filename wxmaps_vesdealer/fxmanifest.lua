fx_version 'cerulean'
games {'gta5'}

author 'wolvezx - wxmaps team'
description 'Vespucci Dealership, for support join our discord https://discord.gg/sSR2M8c78v'

this_is_a_map "yes"

lua54 'yes'

files {
	'audio/wx_vesdealer_doors_game.dat151.rel',
}

client_scripts {
	'client/*'
}

escrow_ignore {
	'stream/TXDs/*',
	'stream/GTA/*'
	
}

dependency 'wxmaps_commons'
dependency 'wxmaps_vesdealer_v'

data_file 'AUDIO_GAMEDATA' 'audio/wx_vesdealer_doors_game.dat'
dependency '/assetpacks'