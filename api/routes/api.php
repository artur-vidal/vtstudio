<?php

use App\Http\Controllers\ApiAuthController;
use App\Http\Controllers\FeedbackController;
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

Route::controller(FeedbackController::class)
    ->prefix('feedbacks')
    ->name('feedbacks.')
    ->group(function() {

        // TODO: implementar algum sistema de roles de usuário para proteger essa rota
        Route::get('/', 'index')->name('index')
            ->middleware('api-token'); 
        Route::post('/', 'store')->name('store')
            ->middleware('loose-api-token');

    });