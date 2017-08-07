import asyncio
import os
import uuid

import unittest

import wsql.cluster
from wsql.cluster.functional import transaction
from wsql.converters import object_row_decoder

from bim.models import payments


_USER_ID = None


class TestCase(unittest.TestCase):
    loop = None
    maxDiff = None

    @classmethod
    def setUpClass(cls):
        connection_args = {
            "master": os.getenv("MYSQL_SERVER", "localhost"),
            "user": os.getenv("MYSQL_USER", "root"),
            "password": os.getenv("MYSQL_PASSWORD", ""),
            "database": os.getenv("MYSQL_DATABASE", "banking"),
            "row_formatter": object_row_decoder
        }
        cls.loop = asyncio.new_event_loop()
        cls.loop.set_debug(True)
        cls.connection = wsql.cluster.connect(connection_args, loop=cls.loop)

    @classmethod
    def tearDownClass(cls):
        cls.loop.close()

    @classmethod
    def synchronize(cls, f):
        if isinstance(f, asyncio.Future) or asyncio.iscoroutine(f):
            return cls.loop.run_until_complete(f)
        return f

    @classmethod
    def user_id_and_email(cls):
        global _USER_ID

        if _USER_ID is None:
            _USER_ID = cls.select("SELECT MAX(user_id) + 1 AS user_id FROM accounts")[0]['user_id']

        _USER_ID += 1

        return _USER_ID, uuid.uuid4().hex

    @classmethod
    def add_money_for(cls, account_id, amount):
        payment = cls.synchronize(payments.start_transaction(cls.connection, account_id, amount))
        cls.synchronize(payments.finish_transaction(
            cls.connection, payment.id, imi_amount=amount, status=0
        ))
        return payment

    @classmethod
    def execute(cls, sql, *args):
        @transaction
        @asyncio.coroutine
        def __query(__connection):
            __cursor = __connection.cursor()
            try:
                yield from __cursor.execute(sql, args)
            finally:
                yield from __cursor.close()

        cls.synchronize(cls.connection.execute(__query))

    @classmethod
    def select(cls, sql, *args):
        @transaction
        @asyncio.coroutine
        def __query(__connection):
            __cursor = __connection.cursor()
            try:
                yield from __cursor.execute(sql, args)
                return (yield from __cursor.fetchxall())
            finally:
                yield from __cursor.close()

        return cls.synchronize(cls.connection.execute(__query))
