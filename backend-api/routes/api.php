<?php

use App\Http\Controllers\ApiAuthController;
use Illuminate\Support\Facades\Route;

Route::get('/me', [ApiAuthController::class, 'me'])
    ->middleware('api-token');

Route::controller(ApiAuthController::class)
    ->prefix('auth')
    ->name('auth.')
    ->group(function() {

        Route::post('/register', 'register')->name('register')
            ->middleware('throttle:5,1');

        Route::post('/login', 'login')->name('login')
            ->middleware('throttle:login');

        Route::post('/refresh', 'refresh')->name('refresh');

        Route::post('/logout', 'logout')->name('logout');

    });