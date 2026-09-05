fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'Nt_Stables'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/configStables.lua',
    'shared/configWagon.lua',
}

client_scripts {
    'client/blips.lua',
    'client/stalls.lua',
    'client/findRoad.lua',
    'client/riding.lua',
    'client/ridingWagon.lua',
    'client/training.lua',
    'client/manageHorses.lua',
    'client/wildHorseRegistration.lua',
    'client/stableZones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/stalls.lua',
    'server/playerHorses.lua',
    'server/auction.lua',
}

files {
    'shared/horse_stats.lua',
    'shared/horse_components.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/imgs/Wagon.png',
    'html/imgs/Horse.png',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'rsg-core',
    'rsg-inventory',
}
