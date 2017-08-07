from bim.models import accounts
from bim.models import constants
from bim.models import journal
from bim.models import statistics
from bim.models import withdraw_queue
from tests.base import TestCase


class TestPayments(TestCase):
    def setUp(self):
        super().setUp()
        self.user_id, self.user_email = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=self.user_id, user_email=self.user_email))

    def test_withdraw_money(self):
        stats1 = self.synchronize(statistics.get_per_day(self.connection))
        self.add_money_for(self.user_id, 100)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(100, account.balance)
        stats2 = self.synchronize(statistics.get_per_day(self.connection))
        withdraw_record = self.synchronize(withdraw_queue.put(
            self.connection, self.user_id, 50, '{"wallet": "test wallet"}'
        ))
        records = self.synchronize(journal.get_all(self.connection, self.user_id))
        # withdraw
        self.assertEqual(constants.BANK_USER_ID, records[0].other_user_id)
        self.assertEqual(journal.ObjectClass.withdraw.value, records[0].object_class)
        self.assertEqual(withdraw_record.id, records[0].object_id)
        self.assertEqual(-50, records[0].amount)
        self.assertEqual(constants.JOURNAL_STATUS_IN_PROCESS, records[0].status)

        stats3 = self.synchronize(statistics.get_per_day(self.connection))
        self.assertEqual(stats2.withdraw_queue.size + 1, stats3.withdraw_queue.size)
        self.assertEqual(stats1.balance.total + 100, stats2.balance.total)
        self.assertEqual(stats1.balance.debit, stats2.balance.debit)
        self.assertEqual(stats2.balance.total, stats3.balance.total)
        self.assertEqual(stats2.balance.debit, stats3.balance.debit)
        self.assertEqual(stats2.balance.credit + 50, stats3.balance.credit)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(50, account.balance)
        self.assertEqual(50, account.frozen)
        withdraw_record = self.synchronize(withdraw_queue.get_all(self.connection))[-1]

        self.synchronize(withdraw_queue.complete(self.connection, withdraw_record.id))
        records = self.synchronize(journal.get_all(self.connection, self.user_id))
        # withdraw
        self.assertEqual(withdraw_record.id, records[0].object_id)
        self.assertEqual(-50, records[0].amount)
        self.assertEqual(constants.BANK_USER_ID, records[0].other_user_id)
        self.assertEqual(journal.ObjectClass.withdraw.value, records[0].object_class)
        self.assertEqual(constants.JOURNAL_STATUS_SUCCESS, records[0].status)

        stats4 = self.synchronize(statistics.get_per_day(self.connection))
        self.assertEqual(stats3.withdraw_queue.size - 1, stats4.withdraw_queue.size)
        self.assertEqual(stats3.balance.total - 50, stats4.balance.total)
        self.assertEqual(stats3.balance.credit - 50, stats4.balance.credit)
        self.assertEqual(
            constants.WITHDRAW_STATUS_SUCCESS,
            self.synchronize(withdraw_queue.get_one(self.connection, withdraw_record.id)).status
        )
        withdraw_records = self.synchronize(withdraw_queue.get_all(self.connection))
        self.assertNotIn(withdraw_record.id, {x.id for x in withdraw_records})

    def test_withdraw_round_algorithm(self, ):
        self.add_money_for(self.user_id, 200)
        for amount in (54, 55):
            withdraw_record = self.synchronize(withdraw_queue.put(
                self.connection, self.user_id, amount, '{"wallet": "test wallet"}'
            ))
            records = self.synchronize(journal.get_all(self.connection, self.user_id))
            # withdraw
            self.assertEqual(constants.BANK_USER_ID, records[0].other_user_id)
            self.assertEqual(journal.ObjectClass.withdraw.value, records[0].object_class)
            self.assertEqual(withdraw_record.id, records[0].object_id)
            self.assertEqual(-amount, records[0].amount)
            self.assertEqual(constants.JOURNAL_STATUS_IN_PROCESS, records[0].status)

    def test_withdraw_fail_if_not_enough_money(self):
        self.add_money_for(self.user_id, 10)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)
        with self.assertRaises(withdraw_queue.exceptions.NotEnoughMoney):
            self.synchronize(withdraw_queue.put(
                self.connection, self.user_id, 50, '{"wallet": "test wallet"}'
            ))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)

    def test_get_for_user(self):
        self.add_money_for(self.user_id, 100)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(100, account.balance)
        record = self.synchronize(withdraw_queue.put(
            self.connection, self.user_id, 50, '{"wallet": "test wallet"}'
        ))
        records = self.synchronize(withdraw_queue.get_for_user(self.connection, self.user_id))
        self.assertIn(record.id, {x.id for x in records})

    def test_clean(self):
        self.add_money_for(self.user_id, 100)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(100, account.balance)
        record = self.synchronize(withdraw_queue.put(
            self.connection, self.user_id, 50, '{"wallet": "test wallet"}'
        ))
        self.synchronize(withdraw_queue.complete(self.connection, record.id))
        self.synchronize(withdraw_queue.clean(self.connection, -1))
        with self.assertRaises(withdraw_queue.exceptions.NotFound):
            self.synchronize(withdraw_queue.get_one(self.connection, record.id))

        records = self.synchronize(journal.get_all(self.connection, self.user_id))
        obj_ids = {x.object_id for x in records if x.object_class == journal.ObjectClass.withdraw.value}
        self.assertNotIn(record.id, obj_ids)

    def test_get_all(self):
        self.add_money_for(self.user_id, 100)
        for _ in range(4):
            self.synchronize(withdraw_queue.put(
                self.connection, self.user_id, 10, '{"wallet": "test wallet"}'
            ))
        requests = self.synchronize(withdraw_queue.get_all(self.connection, max_count=2))
        self.assertEqual(2, len(requests))
        self.assertLess(requests[0].id, requests[1].id)
        requests2 = self.synchronize(withdraw_queue.get_all(self.connection, lower_bound=requests[-1].id, max_count=2))
        self.assertLess(requests[-1].id, requests2[0].id)

    def test_rollback_active(self):
        self.add_money_for(self.user_id, 100)
        request = self.synchronize(withdraw_queue.put(self.connection, self.user_id, 20, '{}'))

        self.synchronize(withdraw_queue.rollback(self.connection, request.id))
        record = self.synchronize(journal.get_all(self.connection, self.user_id))[0]
        self.assertEqual(constants.JOURNAL_STATUS_ROLLBACK, record.status)
        self.assertEqual(journal.ObjectClass.withdraw.value, record.object_class)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(100, account.balance)
        self.assertEqual(0, account.frozen)
        request = self.synchronize(withdraw_queue.get_one(self.connection, request.id))
        self.assertEqual(constants.WITHDRAW_STATUS_ROLLBACK, request.status)

    def test_rollback_completed(self):
        self.add_money_for(self.user_id, 100)
        request = self.synchronize(withdraw_queue.put(self.connection, self.user_id, 20, '{}'))
        self.synchronize(withdraw_queue.complete(self.connection, request.id))

        self.synchronize(withdraw_queue.rollback(self.connection, request.id))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(80, account.balance)
        self.assertEqual(0, account.frozen)

