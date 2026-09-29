<?php

namespace Tests\Feature\Feedback;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Illuminate\Support\Str;
use Tests\TestCase;

class FeedbackTest extends TestCase
{
    use RefreshDatabase, WithFaker;

    public function testFeedbackEhEnviado(): void
    {
        $texto = $this->faker->realText();
        $response = $this->post('/api/feedbacks', compact('texto'), $this->apiHeaders());
        $response->assertStatus(201);
        $this->assertDatabaseHas('feedbacks', compact('texto'));
    }

    public function testFeedbackEhEnviadoPorUsuarioLogado(): void
    {
        $this->actingAsApiUser();

        $texto = $this->faker->realText();
        $this->post('/api/feedbacks', compact('texto'), $this->apiHeaders());
        $this->assertDatabaseHas('feedbacks', ['usuario_id' => auth()->id()]);
    }

    public function testFeedbackAnonimoEnviadoPorUsuarioLogadoNaoGuardaId(): void
    {
        $this->actingAsApiUser();

        $texto = $this->faker->realText();
        $this->post('/api/feedbacks', ['texto' => $texto, 'anonimo' => true], $this->apiHeaders());
        $this->assertDatabaseMissing('feedbacks', ['usuario_id' => auth()->id()]);
    }

    public function testFeedbackMuitoLongoEhInvalido(): void
    {
        $this->actingAsApiUser();

        $texto = Str::random(65536);
        $res = $this->post('/api/feedbacks', ['texto' => $texto, 'anonimo' => true], $this->apiHeaders());

        $res->assertStatus(422);
        $res->assertInvalid('texto');
        $this->assertDatabaseMissing('feedbacks', ['texto' => $texto]);
    }

    public function testFeedbackComValorDeAnonimoNaoBooleanoEhInvalido(): void
    {
        $this->actingAsApiUser();

        $texto = fake()->realText();
        $res = $this->post('/api/feedbacks', ['texto' => $texto, 'anonimo' => 56.4], $this->apiHeaders());

        $res->assertStatus(422);
        $res->assertInvalid('anonimo');
        $this->assertDatabaseMissing('feedbacks', ['texto' => $texto]);
    }
}
