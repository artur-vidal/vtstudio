<?php

namespace Tests\Feature\Auth;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    public function testUsuarioLogadoPodeAcessarRotaProtegida(): void
    {
        $auth = $this->actingAsApiUser();

        $userRes = $this->get('/api/me', [
            ...$this->apiHeaders(),
            'Authorization' => 'Bearer ' . $auth['accessToken']
        ]);
        $userRes->assertStatus(200);
    }

    public function testVisitanteNaoPodeAcessarRotaProtegida(): void
    {
        $userRes = $this->get('/api/me', $this->apiHeaders());
        $userRes->assertStatus(401);
    }

    public function testUsuarioRecemDeslogadoNaoPodeAcessarRotaProtegida(): void
    {
        $auth = $this->actingAsApiUser();

        $this->post('/api/auth/logout', ['refreshToken' => $auth['refreshToken']], $this->apiHeaders());

        $userRes = $this->get('/api/me', [
            ...$this->apiHeaders(),
            'Authorization' => 'Bearer ' . $auth['accessToken']
        ]);
        $userRes->assertStatus(401);
    }
}
