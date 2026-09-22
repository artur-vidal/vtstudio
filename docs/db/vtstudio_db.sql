CREATE TABLE `preferencias`(
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nome` VARCHAR(100) NOT NULL,
    `descricao` TEXT NOT NULL
);
CREATE TABLE `usuario_preferencia`(
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` INT UNSIGNED NOT NULL,
    `preferencia_id` INT UNSIGNED NOT NULL,
    `valor` VARCHAR(100) NOT NULL
);
ALTER TABLE
    `usuario_preferencia` ADD INDEX `usuario_preferencia_usuario_id_index`(`usuario_id`);
ALTER TABLE
    `usuario_preferencia` ADD INDEX `usuario_preferencia_preferencia_id_index`(`preferencia_id`);
CREATE TABLE `feedbacks`(
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` INT UNSIGNED NULL,
    `texto` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP());
ALTER TABLE
    `feedbacks` ADD INDEX `feedbacks_usuario_id_index`(`usuario_id`);
CREATE TABLE `usuario_permissao`(
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_mesa_id` INT UNSIGNED NOT NULL,
    `permissao_id` INT UNSIGNED NOT NULL
);
ALTER TABLE
    `usuario_permissao` ADD INDEX `usuario_permissao_usuario_mesa_id_index`(`usuario_mesa_id`);
ALTER TABLE
    `usuario_permissao` ADD INDEX `usuario_permissao_permissao_id_index`(`permissao_id`);
CREATE TABLE `usuarios`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nome` VARCHAR(100) NOT NULL,
    `email` VARCHAR(255) NOT NULL,
    `senha` CHAR(60) NULL,
    `google_id` VARCHAR(255) NULL,
    `avatar_url` VARCHAR(255) NOT NULL,
    `verified_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE
    `usuarios` ADD UNIQUE `usuarios_email_unique`(`email`);
CREATE TABLE `recuperar_senhas`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` BIGINT UNSIGNED NOT NULL,
    `token` VARCHAR(255) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE `permissoes`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nome` VARCHAR(255) NOT NULL,
    `descricao` TEXT NOT NULL
);
CREATE TABLE `mesas`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `dono_id` BIGINT UNSIGNED NOT NULL,
    `nome` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE `mesas_ativas`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `mesa_id` BIGINT UNSIGNED NOT NULL,
    `codigo` SMALLINT UNSIGNED NOT NULL,
    `closed_at` TIMESTAMP NOT NULL
);
CREATE TABLE `usuario_mesa`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` BIGINT UNSIGNED NOT NULL,
    `mesa_id` BIGINT UNSIGNED NOT NULL
);
CREATE TABLE `pagamentos`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE `refresh_tokens`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` BIGINT UNSIGNED NOT NULL,
    `token_hash` VARCHAR(255) NOT NULL,
    `family_id` CHAR(36) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `revoked_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE `google_credenciais`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `usuario_id` BIGINT UNSIGNED NOT NULL,
    `google_id` VARCHAR(255) NOT NULL,
    `google_refresh` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE
    `usuario_permissao` ADD CONSTRAINT `usuario_permissao_usuario_mesa_id_foreign` FOREIGN KEY(`usuario_mesa_id`) REFERENCES `usuario_mesa`(`usuario_id`);
ALTER TABLE
    `pagamentos` ADD CONSTRAINT `pagamentos_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `refresh_tokens` ADD CONSTRAINT `refresh_tokens_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `mesas` ADD CONSTRAINT `mesas_dono_id_foreign` FOREIGN KEY(`dono_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `mesas_ativas` ADD CONSTRAINT `mesas_ativas_mesa_id_foreign` FOREIGN KEY(`mesa_id`) REFERENCES `mesas`(`id`);
ALTER TABLE
    `usuario_permissao` ADD CONSTRAINT `usuario_permissao_permissao_id_foreign` FOREIGN KEY(`permissao_id`) REFERENCES `permissoes`(`id`);
ALTER TABLE
    `recuperar_senhas` ADD CONSTRAINT `recuperar_senhas_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `usuario_mesa` ADD CONSTRAINT `usuario_mesa_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `google_credenciais` ADD CONSTRAINT `google_credenciais_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `usuario_mesa` ADD CONSTRAINT `usuario_mesa_mesa_id_foreign` FOREIGN KEY(`mesa_id`) REFERENCES `mesas`(`id`);
ALTER TABLE
    `feedbacks` ADD CONSTRAINT `feedbacks_id_foreign` FOREIGN KEY(`id`) REFERENCES `usuarios`(`id`);
ALTER TABLE
    `usuario_preferencia` ADD CONSTRAINT `usuario_preferencia_preferencia_id_foreign` FOREIGN KEY(`preferencia_id`) REFERENCES `preferencias`(`id`);
ALTER TABLE
    `usuario_preferencia` ADD CONSTRAINT `usuario_preferencia_usuario_id_foreign` FOREIGN KEY(`usuario_id`) REFERENCES `usuarios`(`id`);