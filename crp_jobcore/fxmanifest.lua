fx_version 'adamant'
game 'gta5'
lua54 'yes'

author "CentrumRP"
description 'JobCore'
version '1.0.11'

ui_page "web/index.html"

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'resources/**/s_*.lua',
}

client_scripts {
    'resources/**/c_*.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'resources/**/d_*.lua'
}

files {
    'modules/**/*',
    'web/index.html',
    'web/bossmenu.js',

    'web/vendor/tailwind.css',
    'web/vendor/fonts.css',
    'web/vendor/fonts/*.woff2',
    'web/vendor/quill.js',
    'web/vendor/quill.core.css',

    'web/logos/*.png'
}