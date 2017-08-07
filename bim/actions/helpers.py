import asyncio
import functools

from wsql import Error, handle_error
from wsql.cluster import transaction

from bim.models import exceptions


def query(q):
    if callable(q):
        return _query_function(asyncio.coroutine(q))
    if isinstance(q, (str, bytes)):
        return _query_str()
    raise ValueError("Unexpected type: %s" % type(q))


def _query_function(func):
    @functools.wraps(func)
    def wrapped(connection, *args, **kwargs):
        @transaction
        @asyncio.coroutine
        def __query(__connection):
            return (yield from func(__connection, *args, **kwargs))

        try:
            return (yield from connection.execute(__query))
        except Error as e:
            raise handle_error(exceptions, e)

    return wrapped


def _query_str(q):
    @asyncio.coroutine
    def wrapped(connection, *args):
        @transaction
        @asyncio.coroutine
        def __query(__connection):
            __cursor = __connection.cursor()
            try:
                yield from __cursor.execute(q, args)
                return (yield from __cursor.fetchxall())
            finally:
                yield from __cursor.close()

        try:
            return (yield from connection.execute(__query))
        except Error as e:
            raise handle_error(exceptions, e)

    return wrapped
