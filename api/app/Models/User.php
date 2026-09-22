<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use Notifiable;

    public $timestamps = false;
    protected $table = 'usuarios';

    protected $guarded = ['id', 'created_at', 'updated_at'];
    protected $casts = [
        'senha' => 'hashed'
    ];

    protected $hidden = ['password'];
}
