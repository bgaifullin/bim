import argparse
import asyncio
import functools
import inspect
import logging
import sys
import json

import wsql.cluster


class JsonEncoderSafe(json.JSONEncoder):
    def default(self, o):
        return str(o)


def bind_function_arguments(func, args):
    signaute = inspect.signature(func)
    parameters = signaute.parameters

    parser = argparse.ArgumentParser()
    for n, param in parameters.items():
        if n != 'connection':
            parser.add_argument(
                '--{0}'.format(n),
                default=param.default,
                help='The argument {0} of function {1}'.format(n, func.__name__)
            )
    parsed_args = parser.parse_args(args)
    kwargs = {k: getattr(parsed_args, k) for k in parameters if k != 'connection'}
    return functools.partial(func, **kwargs)


def get_argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-H', dest='host', default='localhost')
    parser.add_argument('-p', dest='port', default=3306, type=int)
    parser.add_argument('-u', dest='user', default='')
    parser.add_argument('-P', dest='password', default='')
    parser.add_argument('-d', dest='database', default='imigo_bank')
    parser.add_argument('-f', '--function', required=True)

    return parser.parse_known_args()


def import_function(name):
    name = 'imigo_bank.' + name
    parts = name.split('.')
    obj = __import__('.'.join(parts[:-1]), None, None, [parts[-1]], 0)
    try:
        return getattr(obj, parts[-1])
    except AttributeError:
        raise ImportError("No module named %s" % parts[-1])


def main():
    logging.basicConfig()

    common_args, rest = get_argument_parser()
    func = bind_function_arguments(
        import_function(common_args.function),
        rest
    )
    loop = asyncio.get_event_loop()
    connection = wsql.cluster.connect(
        {
            "master": "{0}:{1}".format(common_args.host, common_args.port),
            "user": common_args.user,
            "password": common_args.password,
            "database": common_args.database,
        },
        loop=loop,
        logger=logging.getLogger()
    )

    result = loop.run_until_complete(func(connection))
    if result is not None:
        json.dump(result, sys.stdout, indent=4, sort_keys=True, cls=JsonEncoderSafe)


if __name__ == '__main__':
    try:
        main()
        sys.exit(0)
    except Exception as e:
        logging.exception(str(e))
        sys.exit(1)
