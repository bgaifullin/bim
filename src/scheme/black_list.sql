CREATE TABLE IF NOT EXISTS `cards_black_list` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `card_number` VARCHAR(255) NOT NULL,
  `errors_count` INTEGER DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `card_number_idx` (`card_number`)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS `payout_codes_blacklist` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `code_idx` (`code`)
) ENGINE=InnoDB;

DELIMITER $$

DROP PROCEDURE IF EXISTS `__black_list_add_card`$$
CREATE PROCEDURE `__black_list_add_card`(card_number VARCHAR(255))
BEGIN
  INSERT INTO cards_black_list (`card_number`, `errors_count`) VALUES (card_number, 1)
    ON DUPLICATE KEY UPDATE errors_count = errors_count + 1;
END$$


DROP PROCEDURE IF EXISTS `__black_list_check_card`$$
CREATE PROCEDURE `__black_list_check_card`(card_number VARCHAR(255), tolerance INTEGER)
BEGIN
  DECLARE errors_count INTEGER DEFAULT -1;
  DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

  SELECT bl.errors_count INTO errors_count FROM cards_black_list bl WHERE bl.card_number=card_number;
  IF errors_count > tolerance THEN
    $THROW2("Forbidden", "The card in black list. ID: ", card_number);
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__black_list_ensure_promo_code_valid`$$
CREATE PROCEDURE `__black_list_ensure_promo_code_valid`(code VARCHAR(255))
BEGIN
  DECLARE CONTINUE HANDLER FOR $_ERR_DUP_ENTRY $THROW2("Forbidden", "The promo code is not valid. ID: ", code);
  INSERT INTO payout_codes_blacklist (`code`) VALUES (code);
END$$

DELIMITER ;