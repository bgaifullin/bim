from bim.models import accounts
from bim.models import constants
from bim.models import journal
from bim.models import withdraw_queue
from tests.base import TestCase


class TestPayments(TestCase):
    def setUp(self):
        super().setUp()
        self.user_id, self.user_email = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=self.user_id, user_email=self.user_email))
        for _ in range(3):
            self.add_money_for(self.user_id, 100)

    def test_poll(self):
        records = self.synchronize(journal.poll(self.connection, None, 1))
        self.assertEqual(1, len(records))
        last_record = records[-1]
        records = self.synchronize(journal.poll(self.connection, records[-1].id))
        self.assertGreater(len(records), 1)
        self.assertIsNone(next((r for r in records if r.id == last_record.id), None))

    def test_get_all(self):
        records = self.synchronize(journal.get_all(self.connection, self.user_id, None, 1))
        self.assertEqual(1, len(records))
        last_id = records[-1].id
        records = self.synchronize(journal.get_all(self.connection, self.user_id, last_id))
        self.assertEqual(5, len(records))
        self.assertLess(records[-1].id, last_id)

    def test_get_all_payments(self):
        # no payments
        self.assertEqual([], self.synchronize(journal.get_all_payments(self.connection, self.user_id)))
        request = self.synchronize(withdraw_queue.put(self.connection, self.user_id, 10, '{}'))
        records = self.synchronize(journal.get_all_payments(self.connection, self.user_id))
        # withdraw
        self.assertEqual(1, len(records))
        self.assertEqual(request.id, records[0].object_id)
        self.assertEqual(constants.JOURNAL_STATUS_IN_PROCESS, records[0].status)
        self.synchronize(withdraw_queue.complete(self.connection, request.id))
        records = self.synchronize(journal.get_all_payments(self.connection, self.user_id))
        self.assertEqual(1, len(records))
        self.assertEqual(request.id, records[0].object_id)
        self.assertEqual(constants.JOURNAL_STATUS_SUCCESS, records[0].status)

    def test_get_all_payments_by_class(self):
        # no payments
        self.assertEqual(
            [],
            self.synchronize(journal.get_payments_by_class(
                self.connection, self.user_id, journal.ObjectClass.withdraw.value
            ))
        )
        request = self.synchronize(withdraw_queue.put(self.connection, self.user_id, 10, '{}'))
        records = self.synchronize(journal.get_payments_by_class(
            self.connection, self.user_id, journal.ObjectClass.withdraw.value
        ))
        self.assertEqual(1, len(records))
        self.assertEqual(request.id, records[0].object_id)
        self.assertEqual(constants.JOURNAL_STATUS_IN_PROCESS,
                         records[0].status)
        self.synchronize(withdraw_queue.complete(self.connection, request.id))
        records = self.synchronize(journal.get_payments_by_class(
            self.connection, self.user_id, journal.ObjectClass.withdraw.value
        ))
        self.assertEqual(1, len(records))
        self.assertEqual(request.id, records[0].object_id)
        self.assertEqual(constants.JOURNAL_STATUS_SUCCESS, records[0].status)
