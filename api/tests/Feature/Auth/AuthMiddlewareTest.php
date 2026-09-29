<?php

namespace Tests\Feature\Auth;

use App\Http\Middleware\AdminMiddleware;
use App\Http\Middleware\ApiTokenMiddleware;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Tests\TestCase;

class AuthMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    public function testUsuarioLogadoPodeAcessarRotaProtegida(): void
    {
        $this->actingAsApiUser();

        $userRes = $this->get('/api/me', $this->apiHeaders());
        $userRes->assertStatus(200);
    }

    public function testVisitanteNaoPodeAcessarRotaProtegida(): void
    {
        $userRes = $this->get('/api/me', $this->apiHeaders());
        $userRes->assertStatus(401);
    }

    public function testUsuarioRecemDeslogadoNaoPodeAcessarRotaProtegida(): void
    {
        $auth = $this->actingAsApiUser();

        $this->post('/api/auth/logout', ['refreshToken' => $auth['refreshToken']], $this->apiHeaders());

        $userRes = $this->get('/api/me', [
            ...$this->apiHeaders(),
            'Authorization' => 'Bearer ' . $auth['accessToken']
        ]);
        $userRes->assertStatus(401);
    }

    public function testUsuarioAdministradorPodeAcessarRotaProtegidaParaAdministrador(): void
    {
        $this->actingAsApiUser(true);

        $req = Request::create('/');
        foreach ($this->apiHeaders() as $h => $v) {
            $req->headers->set($h, $v);
        }

        $tokenMiddleware = new ApiTokenMiddleware();
        $adminMiddleware = new AdminMiddleware();

        $res = $tokenMiddleware->handle($req, function (Request $request) use ($adminMiddleware) {
            return $adminMiddleware->handle($request, function () {
                return new Response();
            });
        });

        $this->assertEquals(200, $res->getStatusCode());
    }

    public function testUsuarioComumNaoPodeAcessarRotaProtegidaParaAdministradores(): void
    {
        $this->actingAsApiUser();

        $req = Request::create('/api/me');
        $middleware = new AdminMiddleware();
        $res = $middleware->handle($req, function () {
        });

        $this->assertEquals(403, $res->getStatusCode());
    }
}
