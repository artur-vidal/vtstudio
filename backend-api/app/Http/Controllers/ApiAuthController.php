<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\JwtService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class ApiAuthController extends Controller
{
    public function __construct(
        public JwtService $jwt
    )
    {
        $this->jwt = new JwtService;
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
            'data' => [
                'accessToken' => $this->jwt->createAccess($user),
                'refreshToken' => $this->jwt->createRefresh($user),
                'user' => $user->toResource()
            ],
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
            'accessToken' => $this->jwt->createAccess($user),
            'refreshToken' => $this->jwt->createRefresh($user)
        ], 200);
    }
}
