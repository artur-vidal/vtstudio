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
        'redirect' => env('GODOT_REDIRECT_SERVER', 'http://localhost:11060'),
        'ttl' => env('GODOT_TTL', 120),
    ],
];