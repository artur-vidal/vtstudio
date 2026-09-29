<?php

namespace App\Http\Middleware;

use App\Exceptions\Auth\InvalidTokenException;
use App\Exceptions\Auth\MissingTokenException;
use App\Exceptions\Auth\SessionRevokedException;
use App\Services\AuthService;
use Closure;
use Firebase\JWT\ExpiredException;
use Illuminate\Http\Request;
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
        try {
            $user = app()->make(AuthService::class)->authenticate($request);
        } catch (MissingTokenException) {
            return response()->json([
                'message' => 'Token faltando.'
            ], 401);
        } catch (ExpiredException | InvalidTokenException | SessionRevokedException) {
            return response()->json([
                'message' => 'Token expirado.'
            ], 401);
        } catch (\Exception $e) {
            return response()->json([
                'message' => $e->getMessage()
            ], 422);
        }

        return $next($request);
    }
}
