<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected $seed = true;

    protected function apiHeaders(): array
    {
        return [
            'Accept' => 'application/json',
            'Content-Type' => 'multipart/form-data',
        ];
    }

    protected function actingAsApiUser(): array
    {
        $user = \App\Models\User::factory()->create();
        $response = $this->post('/api/auth/login', [
            'email' => $user->email,
            'senha' => 'Persona6',
        ], $this->apiHeaders());

        return [
            'user' => $user,
            'accessToken' => $response->json('accessToken'),
            'refreshToken' => $response->json('refreshToken'),
        ];
    }
}
