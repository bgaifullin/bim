import os

from setuptools import setup


def _read(filename):
    with open(filename) as r:
        return r.read().strip()


def find_requires():
    dir_path = os.path.dirname(os.path.realpath(__file__))
    with open('{0}/requirements.txt'.format(dir_path), 'r') as reqs:
        return [x for x in reqs.readlines() if not x.startswith('#')]


setup(
    name='bim',
    version=_read('version.txt'),
    description='Banking Module',
    packages=['bim', 'bim.models', 'bim.actions'],
    zip_safe=False,
    install_requires=find_requires(),
    author="Alexander Nevskiy",
    author_email="kepkin@gmail.com",
    maintainer="Alexander Nevskiy",
    maintainer_email="kepkin@gmail.com",
    url='https://bitbucket.org/itkaboom/imigo-bank',
    license='Other/Proprietary License',
    long_description=_read('README.rst'),
    include_package_data=True,
    package_data={'': ['*.sql']},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Other Environment",
        "License :: Other/Proprietary License",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3.4",
        "Topic :: WEB",
    ],
    entry_points={
        'console_scripts': [
            'bim_ctl = bim.cli:main',
        ],
    }
)
