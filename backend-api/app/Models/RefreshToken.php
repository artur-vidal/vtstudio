<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RefreshToken extends Model
{
    protected $guarded = ['id', 'created_at', 'updated_at'];
    protected $casts = ['expires_at' => 'datetime'];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class);
    }
}
