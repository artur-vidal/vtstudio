<?php

namespace Tests\Feature\Auth;

use App\Models\RefreshToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function testUsuarioLogadoPodeDeslogarEDestroiASessao(): void
    {
        $auth = $this->actingAsApiUser();
        $userId = $auth['user']->id;
        $refreshToken = $auth['refreshToken'];

        $logoutRes = $this->post('/api/auth/logout', ['refreshToken' => $refreshToken], $this->apiHeaders());
        $logoutRes->assertStatus(200);

        $this->assertDatabaseHas('refresh_tokens', ['usuario_id' => $userId]);
        $this->assertDatabaseMissing('refresh_tokens', ['revoked_at' => null]);
    }
}
