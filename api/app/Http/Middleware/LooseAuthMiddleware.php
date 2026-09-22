<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\TokenService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class LooseAuthMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        if($token) {
            try {
                $token_data = (new TokenService)->decode($token);
                $user = User::find($token_data->sub);
                Auth::login($user);
            } catch(\Exception) {}
        }
        
        return $next($request);
    }
}
