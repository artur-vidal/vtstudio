<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\AuthService;
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
        try {
            app()->make(AuthService::class)->authenticate($request);
        } catch (\Exception) {
            // aqui não precisa quebrar
        }

        return $next($request);
    }
}
