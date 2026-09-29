<?php

namespace Tests\Feature\Feedback;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class FeedbackTest extends TestCase
{
    public function testFeedbackEhEnviado(): void
    {
        $texto = fake()->realText();
        $response = $this->post('/api/feedbacks', compact('texto'), $this->apiHeaders());
        $response->assertStatus(201);
        $this->assertDatabaseHas('feedbacks', compact('texto'));
    }

    public function testFeedbackEhEnviadoPorUsuarioLogado(): void
    {
        $this->actingAsApiUser();

        $texto = fake()->realText();
        $this->post('/api/feedbacks', compact('texto'), $this->apiHeaders());
        $this->assertDatabaseHas('feedbacks', ['usuario_id' => auth()->id()]);
    }

    public function testFeedbackAnonimoEnviadoPorUsuarioLogadoNaoGuardaId(): void
    {
        $this->actingAsApiUser();

        $texto = fake()->realText();
        $this->post('/api/feedbacks', ['texto' => $texto, 'anonimo' => true], $this->apiHeaders());
        $this->assertDatabaseMissing('feedbacks', ['usuario_id' => auth()->id()]);
    }
}
