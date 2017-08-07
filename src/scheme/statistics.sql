DELIMITER $$

#define GET_MONEY(user_id, var) \
  SELECT accounts.balance INTO $var FROM accounts WHERE accounts.user_id = $user_id


DROP PROCEDURE IF EXISTS `statistics::get_per_day`$$
CREATE PROCEDURE `statistics::get_per_day` ()
BEGIN
  DECLARE total_money $TYPE_MONEY DEFAULT 0;
  DECLARE earned_money $TYPE_MONEY DEFAULT 0;
  DECLARE withdraw_money $TYPE_MONEY DEFAULT 0;
  DECLARE withdraw_queue_size BIGINT DEFAULT 0;
  DECLARE active_subscriptions_count BIGINT DEFAULT 0;
  DECLARE begin_of_day DATETIME DEFAULT DATE_FORMAT(NOW(),"%Y-%m-%d 00:00:00");

  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW("InternalError", "Database consistency error.");

  $GET_MONEY($AGGREGATOR_ID, total_money);
  $GET_MONEY($SYSTEM_USER_ID, earned_money);

  SELECT COUNT(1), SUM(q.amount) INTO withdraw_queue_size, withdraw_money FROM withdraw_queue q WHERE q.status = $WITHDRAW_STATUS_IN_PROCESS;

  SELECT
    total_money AS `balance.total`,
    earned_money AS `balance.debit`,
    IFNULL(withdraw_money, 0) AS `balance.credit`,
    withdraw_queue_size AS `withdraw_queue.size`;

END$$

DELIMITER ;
