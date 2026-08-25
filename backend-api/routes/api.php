<?php

use App\Http\Controllers\GoogleAuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::controller(GoogleAuthController::class)
    ->prefix('auth/google')
    ->group(function() {

        Route::get('/redirect', 'redirect');
        Route::get('/callback', 'callback');

    });

Route::get('/me', function(Request $request) {
    return $request->user();
})->middleware('api-token');