<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\TokenService;
use Closure;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\JWT;
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

        try {
            $token_data = (new TokenService)->decode($token);
        } catch(ExpiredException $e) {
            return response()->json([
                'message' => 'Token expirado.'
            ], 401);
        } catch(\Exception $e) {
            $token_data = null;
        }
        
        if(!$token_data || !($user = User::find($token_data->sub))) {
            return response()->json([
                'message' => 'Token inválido.'
            ], 401);
        }

        Auth::login($user);
        return $next($request);
    }
}
