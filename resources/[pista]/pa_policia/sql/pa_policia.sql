-- pa_policia: as tabelas são criadas sozinhas quando o script liga.
-- Este arquivo é só para referência ou para criar na mão.

CREATE TABLE IF NOT EXISTS `pa_policia_multas` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `nome` VARCHAR(100) NOT NULL DEFAULT '',
    `valor` INT NOT NULL,
    `motivo` VARCHAR(255) NOT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `policial_cid` VARCHAR(50) NULL,
    `pago` TINYINT NOT NULL DEFAULT 0,
    `cancelada` TINYINT NOT NULL DEFAULT 0,
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `pa_policia_prisoes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `nome` VARCHAR(100) NOT NULL DEFAULT '',
    `meses` INT NOT NULL,
    `multa` INT NOT NULL DEFAULT 0,
    `artigos` TEXT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `pa_policia_presos` (
    `citizenid` VARCHAR(50) PRIMARY KEY,
    `restante` INT NOT NULL,
    `total` INT NOT NULL,
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `pa_policia_bos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `titulo` VARCHAR(150) NOT NULL,
    `descricao` TEXT NULL,
    `envolvidos` TEXT NULL,
    `apreensoes` TEXT NULL,
    `pericias` TEXT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `policial_cid` VARCHAR(50) NULL,
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `pa_policia_mandados` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `tipo` VARCHAR(10) NOT NULL,
    `citizenid` VARCHAR(50) NULL,
    `imovel` INT NULL,
    `motivo` VARCHAR(255) NOT NULL DEFAULT '',
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `expira` INT NOT NULL,
    `ativo` TINYINT NOT NULL DEFAULT 1,
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `pa_policia_licencas` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `tipo` VARCHAR(20) NOT NULL,
    `validade` INT NOT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `revogada` TINYINT NOT NULL DEFAULT 0,
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `pa_policia_placas` (
    `plate` VARCHAR(16) PRIMARY KEY,
    `motivo` VARCHAR(255) NOT NULL DEFAULT '',
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `pa_policia_veiculos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(16) NOT NULL,
    `tipo` VARCHAR(20) NOT NULL,
    `resultado` TEXT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX (`plate`)
);

CREATE TABLE IF NOT EXISTS `pa_policia_apreensoes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NULL,
    `nome` VARCHAR(100) NOT NULL DEFAULT '',
    `itens` TEXT NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `pa_policia_pericias` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `tipo` VARCHAR(20) NOT NULL,
    `dados` TEXT NULL,
    `resultado` VARCHAR(255) NOT NULL DEFAULT '',
    `citizenid` VARCHAR(50) NULL,
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `pa_policia_codigo` (
    `id` VARCHAR(10) PRIMARY KEY,
    `titulo` VARCHAR(150) NOT NULL,
    `multa` INT NOT NULL DEFAULT 0,
    `meses` INT NOT NULL DEFAULT 0,
    `removido` TINYINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `pa_policia_patio` (
    `plate` VARCHAR(16) PRIMARY KEY,
    `tipo` VARCHAR(10) NOT NULL,
    `motivo` VARCHAR(255) NOT NULL DEFAULT '',
    `policial` VARCHAR(100) NOT NULL DEFAULT '',
    `criado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
