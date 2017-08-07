# Auto-generated file by wsql-codegen(part of WSQL-SDK)
# 2017-08-07 21:37:00.079033

from asyncio import coroutine
from wsql import Error, handle_error
from wsql.cluster import transaction

from . import exceptions


@coroutine
def get_per_day(connection):
    """
    get the per of day of the statistics

    :param connection: the connection object
    :returns: ("balance.credit", "balance.debit", "balance.total", "withdraw_queue.size")
    :raises: InternalError
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"statistics::get_per_day", ())
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)
