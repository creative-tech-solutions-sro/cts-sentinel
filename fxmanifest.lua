fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'CTS'
description 'CTS Sentinel - Advanced Server-Authoritative Anti-Cheat & Dashboard'
version '2.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/config.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/map.glb'
}


dependencies {
    'es_extended',
    'ox_lib'
}

exports {
    'VerifyAction'
}
