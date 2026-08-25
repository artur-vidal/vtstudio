<?php

namespace App\Services;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use App\Models\User;
use Illuminate\Support\Str;

class JwtService
{
    private string $secret;

    public function __construct()
    {
        $this->secret = config('app.key'); // reutilizando chave do aplicativos
    }

    public function createAccess(User $user): string
    {
        $payload = [
            'iss' => config('app.url'),
            'iat' => time(),
            'exp' => time() + (60 * 20), // 20 minutos
            'sub' => $user->id
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function createRefresh(User $user): string
    {
        $tokenId = Str::random(40);
        
        $user->update(['refresh_token_id' => $tokenId]);

        $payload = [
            'iss' => config('app.url'),
            'iat' => time(),
            'exp' => time() + (60 * 60 * 24 * 7),
            'jti' => $tokenId // JSON Token ID
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function decode(string $token): ?object
    {
        try {
            return JWT::decode($token, new Key($this->secret, 'HS256'));
        } catch (\Exception $e) {
            return null;
        }
    }
}
