<?php

use App\Http\Controllers\ApiAuthController;
use App\Http\Controllers\GoogleAuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/me', function(Request $request) {
    return $request->user();
})->middleware('api-token');

Route::controller(ApiAuthController::class)
    ->prefix('auth')
    ->name('auth.')
    ->group(function() {

        Route::post('/register', 'register')->name('register');
        Route::post('/login', 'login')->name('login');

    });