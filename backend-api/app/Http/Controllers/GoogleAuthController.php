<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\JwtService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Laravel\Socialite\Socialite;

class GoogleAuthController extends Controller
{
    public function redirect(Request $request) {
        session([
            'client_redirect' => $request->query('client_redirect', config('vtstudio.godot.redirect'))
        ]);

        session([
            'client_state' => $request->query('state', $request->query('state'))
        ]);

        /** @disregard */
        return Socialite::driver('google')
            ->scopes(['https://www.googleapis.com/auth/drive.file'])
            ->with(['prompt' => 'consent', 'access_type' => 'offline'])
            ->redirect();
    }

    public function callback(Request $request) {
        try {
            $google_user = Socialite::driver('google')->user();
            $user = User::updateOrCreate(
                ['google_id' => $google_user->getId()],
                [
                    'name' => $google_user->getName(),
                    'email' => $google_user->getEmail(),
                    'google_id' => $google_user->getId(),
                    'google_refresh' => $google_user->refreshToken
                ]
            );

            $redirect = $request->session()->pull('client_redirect');
            $state = $request->session()->pull('client_state');

            // guardando código pro aplicativo por 1 minuto, tempo do request
            $code = \Illuminate\Support\Str::random(32);
            Cache::set("google_auth_code:{$code}", [
                'code' => $code,
                'user' => $user->id
            ], 60);
                
            return redirect("{$redirect}?code={$code}&state={$state}");
            
        } catch(\Exception $e) {
            return redirect()->route('app.auth.google.fallback');
        }
    }

    public function exchange(Request $request) {
        $code = $request->input('code');
        $data = Cache::pull("google_auth_code:{$code}");

        if(!$data) {
            return response()->json(['message' => 'Código inválido.'], 401);
        }

        $user = User::find($data['user']);

        $jwt = new JwtService;

        $access_token = $jwt->createAccess($user);
        $refresh_token = $jwt->createRefresh($user);

        return response()->json([
            'accessToken' => $access_token,
            'refreshToken' => $refresh_token
        ]);
    }
}
