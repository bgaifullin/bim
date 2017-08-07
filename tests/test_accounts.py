from bim.models import accounts
from bim.models import exceptions
from tests.base import TestCase


class TestAccounts(TestCase):
    def test_put(self):
        user_id, user_email = self.user_id_and_email()

        account = self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_email))
        self.assertEqual(user_id, account.user_id)

        account = self.synchronize(accounts.get(self.connection, user_id=user_id))
        self.assertEqual(user_id, account.user_id)
        self.assertEqual(0, account.balance)
        self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_email))

    def test_put_second_try_with_different_id_return_original_id(self):
        user_id_original, user_email = self.user_id_and_email()
        user_id_second, _ = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=user_id_original, user_email=user_email))
        account = self.synchronize(accounts.put(self.connection, user_id=user_id_second, user_email=user_email))
        self.assertEqual(user_id_original, account.user_id)

    def test_put_second_try_with_different_email_throws(self):
        user_id, user_email = self.user_id_and_email()
        _, user_email2 = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_email))

        with self.assertRaises(exceptions.Conflict):
            self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_email2))

    def test_get_raise_not_found(self):
        user_id, _ = self.user_id_and_email()
        with self.assertRaises(exceptions.NotFound):
            self.synchronize(accounts.get(self.connection, user_id=user_id))

    def test_lock_accounts(self):
        user_id1, user_email1 = self.user_id_and_email()
        user_id2, user_email2 = self.user_id_and_email()
        user_emails = {user_id1: user_email1, user_id2: user_email2}
        user_ids = [user_id1, user_id2]
        user_ids.sort()
        for user_id in user_ids:
            self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_emails[user_id]))
        locked = self.synchronize(accounts.lock_accounts(self.connection, ({'user_id': x} for x in reversed(user_ids))))
        self.assertEqual([x.user_id for x in locked], user_ids)

    def test_account_block(self):
        user_id, user_email = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=user_id, user_email=user_email))
        self.synchronize(accounts.block(self.connection, user_id))
        with self.assertRaises(accounts.exceptions.AccountBlocked):
            self.add_money_for(user_id, 100)
