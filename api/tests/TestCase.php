<?php

namespace Tests;

use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected bool $seed = true;
    protected string $accessToken = '';

    protected function apiHeaders(): array
    {
        return array_merge([
            'Accept' => 'application/json',
            'Content-Type' => 'multipart/form-data',
        ], ($this->accessToken) ? [
            'Authorization' => 'Bearer ' . $this->accessToken,
        ] : []);
    }

    protected function actingAsApiUser(bool $admin = false): array
    {
        $factory = User::factory();
        if ($admin) {
            $factory = $factory->admin();
        }

        $user = $factory->create();
        $response = $this->post('/api/auth/login', [
            'email' => $user->email,
            'senha' => 'Persona6',
        ], $this->apiHeaders());

        $this->accessToken = $response->json('accessToken');

        return [
            'user' => $user,
            'accessToken' => $response->json('accessToken'),
            'refreshToken' => $response->json('refreshToken'),
        ];
    }
}
