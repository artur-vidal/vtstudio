<?php

use App\Http\Controllers\GoogleAuthController;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

Route::controller(GoogleAuthController::class)
    ->prefix('auth/google')
    ->group(function() {

        Route::get('/redirect', 'redirect');
        Route::get('/callback', 'callback');
        Route::post('/exchange', 'exchange')->withoutMiddleware(ValidateCsrfToken::class);

    });