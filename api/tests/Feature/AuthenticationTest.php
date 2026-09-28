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

    public function testValidUserIsRegistered(): void
    {
        $response = $this->post('/api/auth/register', $this->getValidUserData(), $this->apiHeaders());
        $response->assertStatus(201);
    }

    public function testUserWithInvalidEmailIsNotRegistered(): void
    {
        $response = $this->post('/api/auth/register', $this->getInvalidEmailUserData(), $this->apiHeaders());
        $response->assertStatus(422);
    }

    public function testUserWithInvalidPasswordIsNotRegistered(): void
    {
        $response = $this->post('/api/auth/register', $this->getInvalidPasswordUserData(), $this->apiHeaders());
        $response->assertStatus(422);
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
            'email' => 'john.persona.com',
            'senha' => 'Persona'
        ];
    }
}
