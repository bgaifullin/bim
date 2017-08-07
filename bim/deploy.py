from os.path import join, dirname
import subprocess


def update_scheme(host, user, password, port=3306):
    password = '-p' + password if password else ''
    with open(join(dirname(__file__), 'scheme.sql'), 'rb') as scheme:
        subprocess.check_call(['mysql', '-h', host, '-P', str(port), '-u', user, password], stdin=scheme)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="localhost", help="The hostname")
    parser.add_argument("--port", default=3306, type=int, help="The port")
    parser.add_argument("--user", default='', help="The username")
    parser.add_argument("--password", default='', help="The password")
    args = parser.parse_args()
    update_scheme(args.host, args.user, args.password, args.port)

if __name__ == '__main__':
    main()
