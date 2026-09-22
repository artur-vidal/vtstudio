<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Feedback extends Model
{
    public $timestamps = false;
    protected $table = 'feedbacks';

    protected $guarded = ['id', 'created_at'];
    protected $casts = [
        'created_at' => 'datetime'
    ];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class, 'usuario_id');
    }
}
