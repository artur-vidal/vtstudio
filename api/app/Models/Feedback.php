<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Feedback extends Model
{
    public $timestamps = false;
    protected $table = 'feedbacks';

    protected $guarded = ['id'];
    protected $casts = [
        'created_at' => 'datetime'
    ];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    protected static function booted() {
        static::creating(function (Model $model) {
            $model->created_at = now();
        });
    }
}
