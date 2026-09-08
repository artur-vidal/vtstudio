<?php

namespace App\Services;

use App\Models\RefreshToken;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use App\Models\User;
use Illuminate\Support\Str;

class TokenService
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
            'exp' => time() + (60 * config('vtstudio.tokens.access_lifetime')), // 20 minutos
            'sub' => $user->id
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function createRefresh(User $user, ?string $family_id = null): string {
        $plain = Str::random(64);

        RefreshToken::create([
            'user_id' => $user->id,
            'family_id' => $family_id ?? Str::uuid(),
            'token_hash' => hash('sha256', $plain),
            'expires_at' => now()->addDays(config('vtstudio.tokens.refresh_lifetime')) // 30 dias
        ]);

        return $plain;
    }
    
    public function decode(string $token): ?object
    {
        return JWT::decode($token, new Key($this->secret, 'HS256'));
    }
}
