<?php

namespace Tests\Feature;

use App\Models\RefreshToken;
use App\Models\User;
use App\Services\TokenService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    public function testUsuarioValidoEhRegistrado(): void
    {
        $res = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders());
        $res->assertStatus(201);
    }

    public function testUsuarioComEmailInvalidoNaoEhRegistrado(): void
    {
        $res = $this->post('/api/auth/register', $this->getInvalidEmailUserData(), $this->apiHeaders());
        $res->assertInvalid('email');
        $res->assertStatus(422);
    }

    public function testUsuarioComSenhaInvalidaNaoEhRegistrado(): void
    {
        $res = $this->post('/api/auth/register', $this->getInvalidPasswordUserData(), $this->apiHeaders());
        $res->assertInvalid('senha');
        $res->assertStatus(422);
    }

    public function testUsuarioComEmailDuplicadoNaoEhRegistrado(): void
    {
        // registra o primeiro
        $res1 = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders());
        $res1->assertStatus(201);

        // tenta registrar o segundo e da errado (espero)
        $res2 = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders());
        $res2->assertInvalid('email');
        $res2->assertStatus(422);
    }

    public function testUsuarioValidoPodeLogarECriaSessao(): void
    {
        $userId = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders())
            ->json('data')['id'];
        $loginRes = $this->post('/api/auth/login', $this->getValidUserData(), $this->apiHeaders());
        $loginRes->assertStatus(200);

        $tokenizer = new TokenService();
        $this->assertEquals($userId, $tokenizer->decode($loginRes->json('accessToken'))->sub);
        $this->assertTrue(RefreshToken::query()->where('usuario_id', $userId)->exists());
    }

    public function testUsuarioLogadoPodeDeslogarEDestroiASessao(): void
    {
        $userId = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders())
            ->json('data')['id'];
        $loginRes = $this->post('/api/auth/login', $this->getValidUserData(), $this->apiHeaders());

        $refreshToken = $loginRes->json('refreshToken');
        $logoutRes = $this->post('/api/auth/logout', ['refreshToken' => $refreshToken], $this->apiHeaders());
        $logoutRes->assertStatus(200);

        $tokenizer = new TokenService();
        $this->assertTrue(RefreshToken::query()->where('usuario_id', $userId)->whereNotNull('revoked_at')->exists());
    }

    public function testUsuarioLogadoPodeAcessarRotaProtegida(): void
    {
        $userId = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders())
            ->json('data')['id'];
        $loginRes = $this->post('/api/auth/login', $this->getValidUserData(), $this->apiHeaders());

        $userRes = $this->get('/api/me', [
            ...$this->apiHeaders(),
            'Authorization' => 'Bearer ' . $loginRes->json('accessToken')
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
        $userId = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders())
            ->json('data')['id'];
        $loginRes = $this->post('/api/auth/login', $this->getValidUserData(), $this->apiHeaders());
        $this->post('/api/auth/logout', ['refreshToken' => $loginRes->json('refreshToken')], $this->apiHeaders());

        $userRes = $this->get('/api/me', [
            ...$this->apiHeaders(),
            'Authorization' => 'Bearer ' . $loginRes->json('accessToken')
        ]);
        $userRes->assertStatus(401);
    }

    protected function getValidUserData(): array
    {
        return [
            'nome' => 'John Persona',
            'email' => 'john.persona@email.com',
            'senha' => 'Persona6'
        ];
    }

    protected function getInvalidEmailUserData(): array
    {
        return [
            'nome' => 'John Persona',
            'email' => 'john.persona.com',
            'senha' => 'Persona6'
        ];
    }

    protected function getInvalidPasswordUserData(): array
    {
        return [
            'nome' => 'John Persona',
            'email' => 'john.persona@email.com',
            'senha' => 'Persona'
        ];
    }
}
