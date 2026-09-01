<?php

use App\Http\Controllers\GoogleAuthController;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

Route::controller(GoogleAuthController::class)
    ->prefix('auth/google')
    ->name('auth.google.')
    ->group(function() {

        Route::get('/redirect', 'redirect')->name('redirect');
        Route::get('/callback', 'callback')->name('callback');
        Route::post('/exchange', 'exchange')->name('exchange')
            ->withoutMiddleware(ValidateCsrfToken::class);

        Route::view('/fallback', 'google-fallback')->name('fallback');

    });