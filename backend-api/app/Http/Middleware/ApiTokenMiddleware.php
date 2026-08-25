<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\JwtService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class ApiTokenMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        if(!$token) {
            return response()->json([
                'message' => 'Token faltando.'
            ], 401);
        }

        $token_data = (new JwtService)->decode($token);
        if(time() > $token_data->exp) {
            return response()->json([
                'message' => 'Sessão expirada.'
            ], 401);
        }

        $user = User::find($token_data->sub);
        if(!$user) {
            return response()->json([
                'message' => 'Token inválido.'
            ], 401);
        }

        Auth::login($user);
        return $next($request);
    }
}
