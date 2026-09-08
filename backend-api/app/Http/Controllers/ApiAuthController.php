<?php

namespace App\Http\Controllers;

use App\Models\RefreshToken;
use App\Models\User;
use App\Services\JwtService;
use App\Services\TokenService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class ApiAuthController extends Controller
{
    public function __construct(
        public TokenService $tokenator
    )
    {
        $this->tokenator = new TokenService;
    }

    public function me(Request $request) {
        return $request->user()->toResource();
    }

    public function register(Request $request) {
        $data = $request->validate([
            'name' => ['required', 'string'],
            'email' => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)
                ->mixedCase()
                ->numbers()
            ],
        ]);

        $user = User::create($data);

        return response()->json([
            'accessToken' => $this->tokenator->createAccess($user),
            'refreshToken' => $this->tokenator->createRefresh($user),
            'data' => $user->toResource()
        ]);
    }

    public function login(Request $request) {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string']
        ]);

        $user = User::firstWhere('email', $data['email']);
        if(!$user || !Hash::check($data['password'], $user->password)) {
            return response()->json([
                'message' => 'Credenciais inválidas. Tente novamente.'
            ], 401);
        }

        return response()->json([
            'accessToken' => $this->tokenator->createAccess($user),
            'refreshToken' => $this->tokenator->createRefresh($user)
        ], 200);
    }

    public function refresh(Request $request) {
        $data = $request->validate([
            'token' => ['required', 'string']
        ]);

        $hash = hash('sha256', $data['token']);
        $stored = RefreshToken::firstWhere('token_hash', $hash);

        // se o token usado já existir mas foi revogado, sinal de que alguém pegou o token. então, revogamos todos.
        if ($stored && $stored->revoked_at) {
            RefreshToken::where('family_id', $stored->family_id)->update(['revoked_at' => now()]);
            return response()->json([
                'message' => 'Sessão comprometida. Faça login novamente.'
            ], 401);
        }

        if (!$stored || $stored->revoked_at || $stored->expires_at->isPast()) {
            return response()->json([
                'message' => 'Token inválido.'
            ], 401);
        }

        $stored->update(['revoked_at' => now()]);
        $user = $stored->user;

        return response()->json([
            'accessToken' => $this->tokenator->createAccess($user),
            'refreshToken' => $this->tokenator->createRefresh($user, $stored->family_id)
        ]);
    }

    public function logout(Request $request) {
        $hash = hash('sha256', $request->input('refreshToken'));
        RefreshToken::where('token_hash', $hash)->update(['revoked_at' => now()]);
        return response()->json(['message' => 'Deslogado com sucesso.']);
    }
}
