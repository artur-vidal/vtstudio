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
        Schema::create('usuarios', function (Blueprint $table) {
            $table->id();
            $table->string('nome', 100);
            $table->string('email', 255)->unique();
            $table->string('senha', 60)->nullable();
            $table->string('avatar_url', 255)->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('preferencias', function (Blueprint $table) {
            $table->id();
            $table->string('nome', 100);
            $table->text('descricao');
        });

        Schema::create('permissoes', function (Blueprint $table) {
            $table->id();
            $table->string('nome', 255);
            $table->text('descricao');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('permissoes');
        Schema::dropIfExists('preferencias');
        Schema::dropIfExists('usuarios');
    }
};
