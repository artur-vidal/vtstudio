<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    public ?User $user = null;

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
