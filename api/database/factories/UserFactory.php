<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'nome' => $this->faker->name(),
            'email' => $this->faker->unique()->safeEmail(),
            'senha' => 'Persona6', // Senha padrão para facilitar testes de login
        ];
    }

    public function admin(): self
    {
        return $this->state(function (array $attributes) {
            return ['admin' => true];
        });
    }
}
