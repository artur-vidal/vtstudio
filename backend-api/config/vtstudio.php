<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Configurações VTStudio
    |--------------------------------------------------------------------------
    |
    | Esse arquivo contém configurações específicas do VTStudio, principalmente
    | aquelas destinadas à interação com o cliente. Este arquivo será muito
    | alterado durante desenvolvimento.
    */

    'godot' => [
        'redirect' => env('GODOT_REDIRECT', env('APP_URL')),
        'ttl' => env('GODOT_TTL', 120),
    ],

    'tokens' => [
        'access_lifetime' => (float) env('ACCESS_LIFETIME', 10),
        'refresh_lifetime' => (float) env('REFRESH_LIFETIME', 30)
    ]
];