<?php

namespace Database\Factories;

use App\Models\Feedback;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Feedback>
 */
class FeedbackFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'texto' => $this->faker->realText()
        ];
    }

    public function author(User $user): self
    {
        return $this->state(function (array $attributes) use ($user) {
            return ['usuario_id' => $user->id];
        });
    }
}
