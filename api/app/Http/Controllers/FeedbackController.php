<?php

namespace App\Http\Controllers;

use App\Models\Feedback;
use Illuminate\Http\Request;

class FeedbackController extends Controller
{
    public function index() {
        // implementar
    }

    public function store(Request $request) {
        $data = $request->validate([
            'texto' => ['required', 'string', 'max:65535']
        ]);

        $feedback = Feedback::create([
            'texto' => $data['texto'],
            'usuario_id' => $request->user()?->id
        ]);

        return response()->json([
            'message' => 'Feedback postado! Obrigado por contribuir para o VTStudio!',
            'data' => $feedback->toResource()
        ], 201);
    }
}
