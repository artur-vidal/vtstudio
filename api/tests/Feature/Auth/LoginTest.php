<?php

namespace Tests\Feature\Auth;

use App\Models\RefreshToken;
use App\Services\TokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function testUsuarioValidoPodeLogarECriaSessao(): void
    {
        // Criamos o usuário via factory para evitar dependência de registro manual
        $user = \App\Models\User::factory()->create();

        $loginRes = $this->post('/api/auth/login', [
            'email' => $user->email,
            'senha' => 'Persona6',
        ], $this->apiHeaders());

        $loginRes->assertStatus(200);

        $tokenizer = new TokenService();
        $this->assertEquals($user->id, $tokenizer->decode($loginRes->json('accessToken'))->sub);
        $this->assertTrue(RefreshToken::query()->where('usuario_id', $user->id)->exists());
    }
}
