<?php

namespace App\Services;

use App\Models\User;
use Google\Client;
use Google\Service\Drive;
use Google\Service\Drive\DriveFile;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\UnauthorizedException;

class GoogleClient {
    protected Client $client;
    protected Drive $driveService;

    public static function for(User $user) {
        if(!$user->googleRefresh) {
            throw new UnauthorizedException('Não autorizado.');
        }

        $client = new Client(config('services.google'));
        $client = new Client(config('services.google'));
        $client->setAccessToken(
            $client->fetchAccessTokenWithRefreshToken($user->refreshToken)
        );

        $drive = new Drive($client);

        $new = new self;
        $new->client = $client;
        $new->driveService = $drive;

        return $new;
    }

    public function getAppFolder(User $user) {
        if($user->drive_folder_id) {
            return $user->drive_folder_id;
        }

        $folder_meta = new DriveFile([
            'name' => config('app.name') . ' Uploads',
            'mimeType' => 'application/vnd.google-apps.folder'
        ]);

        $folder = $this->driveService->files->create($folder_meta, [
            ['fields' => 'id']
        ]);

        $folder_id = $folder->getId();
        $user->update(['drive_folder_id' => $folder_id]);

        return $folder_id;
    }

    public function upload(UploadedFile $file, string $folderId) {
        $file_meta = new DriveFile([
            'name' => $file->getClientOriginalName(),
            'parents' => [$folderId]
        ]);

        $content = $file->getContent();

        return $this->driveService->files->create($file_meta, [
            'data' => $content,
            'mimeType' => $file->getMimeType(),
            'uploadType' => 'multipart',
            'fields' => 'id, webViewLink'
        ]);
    }
}