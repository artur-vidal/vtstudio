<?php

namespace App\Services;

use App\Exceptions\Auth\InvalidTokenException;
use App\Exceptions\Auth\MissingTokenException;
use App\Exceptions\Auth\SessionRevokedException;
use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AuthService
{
    public function __construct(private TokenService $tokenService)
    {
    }

    /**
     * @throws InvalidTokenException
     * @throws MissingTokenException
     * @throws SessionRevokedException
     */
    public function authenticate(Request $request): User
    {
        $token = $request->bearerToken();
        if (!$token) {
            throw new MissingTokenException();
        }

        $tokenData = $this->tokenService->decode($token);
        if (!$this->validateSession($tokenData)) {
            throw new SessionRevokedException();
        }

        $user = User::query()->find($tokenData->sub);
        if ($user) {
            Auth::login($user);
            return $user;
        }

        throw new InvalidTokenException();
    }

    private function validateSession($tokenData): bool
    {
        return RefreshToken::query()
            ->where('id', $tokenData->sid)
            ->where('usuario_id', $tokenData->sub)
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now())
            ->exists();
    }
}
