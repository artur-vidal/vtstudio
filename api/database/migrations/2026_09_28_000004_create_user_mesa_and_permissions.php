<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('usuario_mesa', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('usuarios');
            $table->foreignId('mesa_id')->constrained('mesas');
        });

        Schema::create('usuario_permissao', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_mesa_id')->constrained('usuario_mesa');
            $table->foreignId('permissao_id')->constrained('permissoes');
            $table->index('usuario_mesa_id');
            $table->index('permissao_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('usuario_permissao');
        Schema::dropIfExists('usuario_mesa');
    }
};
